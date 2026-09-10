using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using BasicCompany.Feature.Search.Models;
using Sitecore.Abstractions;
using Sitecore.ContentSearch;
using Sitecore.ContentSearch.Linq;
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
                var queryable = context.GetQueryable<PageSearchQuery>()
                    .Where(result => result.Paths.Contains(root.ID))
                    .Where(result => result.Templates.Contains(Templates.Searchable.Id))
                    .Where(result => !result.ExcludeFromSearch)
                    .Filter(result => result.IsLatestVersion)
                    .Filter(result => result.Language == root.Language.Name);

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
