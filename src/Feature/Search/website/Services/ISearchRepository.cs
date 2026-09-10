using BasicCompany.Feature.Search.Models;
using Sitecore.Data.Items;

namespace BasicCompany.Feature.Search.Services
{
    public interface ISearchRepository
    {
        SearchResultPage Search(Item root, string query, int page, int pageSize);
    }
}
