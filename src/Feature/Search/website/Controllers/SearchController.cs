using System.Diagnostics;
using System.Web.Mvc;
using BasicCompany.Feature.Search.Models;
using BasicCompany.Feature.Search.Services;
using Sitecore.Data.Fields;
using Sitecore.Data.Items;
using Sitecore.Mvc.Presentation;

namespace BasicCompany.Feature.Search.Controllers
{
    public class SearchController : Controller
    {
        public const string QueryParameter = "query";
        public const string PageParameter = "page";

        private const int DefaultPageSize = 9;

        protected readonly ISearchRepository SearchRepository;

        public SearchController(ISearchRepository searchRepository)
        {
            Debug.Assert(searchRepository != null);
            SearchRepository = searchRepository;
        }

        public ActionResult Results()
        {
            var datasource = RenderingContext.Current.Rendering.Item ?? RenderingContext.Current.ContextItem;
            if (datasource == null)
            {
                return null;
            }

            var query = (Request.QueryString[QueryParameter] ?? string.Empty).Trim();
            var page = GetPage();
            var pageSize = GetPageSize(datasource);
            var found = SearchRepository.Search(GetSearchRoot(datasource), query, page, pageSize);

            return View(new SearchResults
            {
                Datasource = datasource,
                Query = query,
                Page = page,
                PageSize = pageSize,
                TotalResults = found.TotalResults,
                Results = found.Items
            });
        }

        protected virtual int GetPage()
        {
            int page;
            if (!int.TryParse(Request.QueryString[PageParameter], out page) || page < 1)
            {
                return 1;
            }

            return page;
        }

        protected virtual int GetPageSize(Item datasource)
        {
            int pageSize;
            if (!int.TryParse(datasource[Templates.SearchResults.Fields.ResultsPerPage], out pageSize) || pageSize < 1)
            {
                return DefaultPageSize;
            }

            return pageSize;
        }

        protected virtual Item GetSearchRoot(Item datasource)
        {
            var field = (ReferenceField)datasource.Fields[Templates.SearchResults.Fields.SearchRoot];
            if (field != null && field.TargetItem != null)
            {
                return field.TargetItem;
            }

            var site = Sitecore.Context.Site;
            if (site == null || Sitecore.Context.Database == null)
            {
                return null;
            }

            return Sitecore.Context.Database.GetItem(site.StartPath);
        }
    }
}
