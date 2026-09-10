using Sitecore.Data;

namespace BasicCompany.Feature.Search
{
    public static class Templates
    {
        public static class Searchable
        {
            public static readonly ID Id = new ID("{7D7E26A9-D499-4EE5-9858-B5E9331BAB1D}");

            public static class Fields
            {
                public static readonly ID SearchTitle = new ID("{BE6E1E93-25CD-41CD-B92A-60EE35B5C6A8}");
                public static readonly ID SearchSummary = new ID("{254EE76E-7AC4-424F-8141-4578E0C27A5E}");
                public static readonly ID SearchImage = new ID("{D6E9A506-AA37-49E1-A492-10A0911BD5D3}");
                public static readonly ID ExcludeFromSearch = new ID("{0B41FB8B-E7EF-414F-B23B-E39DAF5A5DD7}");
            }
        }

        public static class SearchResults
        {
            public static readonly ID Id = new ID("{6E93EBE5-8CA1-468C-97FB-D3DC876F730F}");

            public static class Fields
            {
                public static readonly ID Title = new ID("{A94479BD-E37F-4728-AD30-98900B3CBBCA}");
                public static readonly ID PlaceholderText = new ID("{DAD65B5F-BC1C-46D8-98C4-679D85B77B11}");
                public static readonly ID ResultsPerPage = new ID("{52E227FD-9769-4C99-A06C-8827D118938E}");
                public static readonly ID SearchRoot = new ID("{B4827189-583E-4C09-93F2-F7163F50A318}");
                public static readonly ID NoResultsText = new ID("{9BCAB0BC-6000-408A-B16C-8785AC7AD7EC}");
            }
        }
    }
}
