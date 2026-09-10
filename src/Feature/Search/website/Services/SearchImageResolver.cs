using Sitecore.Data;
using Sitecore.Data.Fields;
using Sitecore.Data.Items;

namespace BasicCompany.Feature.Search.Services
{
    public static class SearchImageResolver
    {
        public const string FallbackImageFieldName = "Image";

        public static ID GetImageFieldId(Item item)
        {
            if (item == null)
            {
                return null;
            }

            if (HasMedia(item.Fields[Templates.Searchable.Fields.SearchImage]))
            {
                return Templates.Searchable.Fields.SearchImage;
            }

            var fallback = item.Fields[FallbackImageFieldName];

            return HasMedia(fallback) ? fallback.ID : null;
        }

        private static bool HasMedia(Field field)
        {
            if (field == null || string.IsNullOrEmpty(field.Value))
            {
                return false;
            }

            return ((ImageField)field).MediaItem != null;
        }
    }
}
