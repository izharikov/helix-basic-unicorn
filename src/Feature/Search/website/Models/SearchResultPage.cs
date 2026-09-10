using System.Collections.Generic;
using Sitecore.Data.Items;

namespace BasicCompany.Feature.Search.Models
{
    public class SearchResultPage
    {
        public IList<Item> Items { get; set; } = new List<Item>();
        public int TotalResults { get; set; }
    }
}
