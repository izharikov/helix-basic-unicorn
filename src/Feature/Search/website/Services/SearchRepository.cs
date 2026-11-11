using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using BasicCompany.Feature.Search.Models;
using Sitecore.Abstractions;
using Sitecore.ContentSearch;
using Sitecore.ContentSearch.Linq;
using Sitecore.ContentSearch.Linq.Utilities;
using Sitecore.Data.Items;

namespace BasicCompany.Feature.Search.Services
{
    public class SearchRepository : ISearchRepository
    {
        protected readonly BaseFactory Factory;
        protected readonly BaseItemManager ItemManager;

        public SearchRepository(BaseFactory factory, BaseItemManager itemManager)
        {
            Debug.Assert(factory != null);
            Debug.Assert(itemManager != null);
            Factory = factory;
            ItemManager = itemManager;
        }

        public SearchResultPage Search(Item root, string query, int page, int pageSize)
        {
            if (root == null || pageSize <= 0)
            {
                return new SearchResultPage();
            }

            using (var context = GetSearchContext(root))
            {
                var queryable = GetPageQueryable(context, root);

                if (!string.IsNullOrWhiteSpace(query))
                {
                    queryable = queryable.Where(result => result.Content.Contains(query));
                }

                var skip = (page - 1) * pageSize;
                var results = queryable.Skip(skip < 0 ? 0 : skip).Take(pageSize).GetResults();

                return new SearchResultPage
                {
                    Items = GetItems(results.Hits.Select(hit => hit.Document.UniqueId)),
                    TotalResults = results.TotalSearchResults
                };
            }
        }

        public IList<Item> Suggest(Item root, string term, int max)
        {
            var tokens = (term ?? string.Empty).Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            if (root == null || max <= 0 || tokens.Length == 0)
            {
                return new List<Item>();
            }

            using (var context = GetSearchContext(root))
            {
                var match = PredicateBuilder.True<PageSearchQuery>();
                foreach (var token in tokens)
                {
                    var value = token;
                    match = match.And(result => result.SearchTitle.StartsWith(value).Boost(5) || result.Content.Contains(value));
                }

                var results = GetPageQueryable(context, root)
                    .Where(match)
                    .Take(max)
                    .GetResults();

                return GetItems(results.Hits.Select(hit => hit.Document.UniqueId));
            }
        }

        protected virtual IQueryable<PageSearchQuery> GetPageQueryable(IProviderSearchContext context, Item root)
        {
            return context.GetQueryable<PageSearchQuery>()
                .Where(result => result.Paths.Contains(root.ID))
                .Where(result => result.Templates.Contains(Templates.Searchable.Id))
                .Where(result => !result.ExcludeFromSearch)
                .Filter(result => result.IsLatestVersion)
                .Filter(result => result.Language == root.Language.Name);
        }

        protected virtual IList<Item> GetItems(IEnumerable<Sitecore.Data.ItemUri> uris)
        {
            return uris
                .Select(uri => ItemManager.GetItem(uri.ItemID, uri.Language, uri.Version, Factory.GetDatabase(uri.DatabaseName)))
                .Where(item => item != null)
                .ToList();
        }

        protected virtual IProviderSearchContext GetSearchContext(Item item)
        {
            return ContentSearchManager.GetIndex((SitecoreIndexableItem)item).CreateSearchContext();
        }
    }
}
