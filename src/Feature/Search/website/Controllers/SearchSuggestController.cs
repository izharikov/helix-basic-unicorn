using System;
using System.Diagnostics;
using System.Linq;
using System.Web.Mvc;
using BasicCompany.Feature.Search.Services;
using Sitecore.Abstractions;
using Sitecore.Data.Items;

namespace BasicCompany.Feature.Search.Controllers
{
    public class SearchSuggestController : Controller
    {
        public const string TermParameter = "term";
        public const string MaxParameter = "max";

        private const int DefaultMaxSuggestions = 5;
        private const int MaxAllowedSuggestions = 10;

        protected readonly ISearchRepository SearchRepository;
        protected readonly BaseLinkManager LinkManager;

        public SearchSuggestController(ISearchRepository searchRepository, BaseLinkManager linkManager)
        {
            Debug.Assert(searchRepository != null);
            Debug.Assert(linkManager != null);
            SearchRepository = searchRepository;
            LinkManager = linkManager;
        }

        [HttpGet]
        public ActionResult Suggest()
        {
            var term = (Request.QueryString[TermParameter] ?? string.Empty).Trim();
            var root = GetSearchRoot();
            if (term.Length == 0 || root == null)
            {
                return Json(new object[0], JsonRequestBehavior.AllowGet);
            }

            var suggestions = SearchRepository.Suggest(root, term, GetMax())
                .Select(item => new
                {
                    title = GetTitle(item),
                    url = LinkManager.GetItemUrl(item)
                })
                .ToArray();

            return Json(suggestions, JsonRequestBehavior.AllowGet);
        }

        protected virtual int GetMax()
        {
            int max;
            if (!int.TryParse(Request.QueryString[MaxParameter], out max) || max < 1)
            {
                return DefaultMaxSuggestions;
            }

            return Math.Min(max, MaxAllowedSuggestions);
        }

        protected virtual Item GetSearchRoot()
        {
            var site = Sitecore.Context.Site;
            if (site == null || Sitecore.Context.Database == null)
            {
                return null;
            }

            return Sitecore.Context.Database.GetItem(site.StartPath);
        }

        protected virtual string GetTitle(Item item)
        {
            var title = item[Templates.Searchable.Fields.SearchTitle];
            return string.IsNullOrEmpty(title) ? item.DisplayName : title;
        }
    }
}
