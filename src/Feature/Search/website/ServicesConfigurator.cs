using Microsoft.Extensions.DependencyInjection;
using Sitecore.DependencyInjection;

namespace BasicCompany.Feature.Search
{
    public class ServicesConfigurator : IServicesConfigurator
    {
        public void Configure(IServiceCollection serviceCollection)
        {
            serviceCollection.AddTransient<Controllers.SearchController>();
            serviceCollection.AddTransient<Services.ISearchRepository, Services.SearchRepository>();
        }
    }
}
