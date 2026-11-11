using Sitecore.Data.Items;

namespace BasicCompany.Feature.Search.Models
{
    public class SearchBox
    {
        public Item Datasource { get; set; }
        public string SearchPageUrl { get; set; }
        public string SuggestUrl { get; set; }
        public int MinCharacters { get; set; }
        public int MaxSuggestions { get; set; }
    }
}
