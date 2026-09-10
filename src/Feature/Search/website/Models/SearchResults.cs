using System;
using System.Collections.Generic;
using Sitecore.Data.Items;

namespace BasicCompany.Feature.Search.Models
{
    public class SearchResults
    {
        public Item Datasource { get; set; }
        public string Query { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public int TotalResults { get; set; }
        public IList<Item> Results { get; set; } = new List<Item>();

        public int TotalPages
        {
            get { return PageSize > 0 ? (int)Math.Ceiling(TotalResults / (double)PageSize) : 0; }
        }

        public bool HasPreviousPage
        {
            get { return Page > 1; }
        }

        public bool HasNextPage
        {
            get { return Page < TotalPages; }
        }
    }
}
