using System.Web.Mvc;
using System.Web.Routing;
using Sitecore.Pipelines;

namespace BasicCompany.Feature.Search.Pipelines
{
    public class RegisterRoutes
    {
        public const string SuggestRouteName = "BasicCompany.Feature.Search.Suggest";
        public const string SuggestUrl = "api/search/suggest";

        public void Process(PipelineArgs args)
        {
            RouteTable.Routes.MapRoute(
                SuggestRouteName,
                SuggestUrl,
                new { controller = "SearchSuggest", action = "Suggest" },
                new[] { "BasicCompany.Feature.Search.Controllers" });
        }
    }
}
