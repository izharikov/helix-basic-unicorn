using System.Collections.Generic;
using Sitecore.ContentSearch;
using Sitecore.Data;

namespace BasicCompany.Feature.Search.Services
{
    public class PageSearchQuery
    {
        [IndexField("_uniqueid")]
        public virtual ItemUri UniqueId { get; set; }
        [IndexField("_path")]
        public virtual IEnumerable<ID> Paths { get; set; }
        [IndexField("_templates")]
        public virtual IEnumerable<ID> Templates { get; set; }
        [IndexField("_content")]
        public virtual string Content { get; set; }
        [IndexField("_latestversion")]
        public virtual bool IsLatestVersion { get; set; }
        [IndexField("_language")]
        public virtual string Language { get; set; }
        [IndexField("exclude from search")]
        public virtual bool ExcludeFromSearch { get; set; }
    }
}
