import ProfilesRnsCrawler as prc
import argparse
import time

def main():
    parser = argparse.ArgumentParser(description="A script to download profile RDF data from a ProfilesRNS website.")
    parser.add_argument("-u", "--url", type=str, help="The URL of the ProfilesRNS website to crawl.")
    parser.add_argument("-o", "--outfile", type=str, help="The output file to write.")
    parser.add_argument("-f", "--rdf_folder", type=str, help="The folder to save RDF data.")
    
    args = parser.parse_args()

    if not args.url or not args.outfile or not args.rdf_folder:
        parser.print_help()
        exit(1)

    # url = "https://profiles.rush.edu/search/default.aspx?searchtype=people&classuri=http://xmlns.com/foaf/0.1/Person&searchfor=&perpage=100&offset=0&page="
    url = args.url

    crawler = prc.ProfilesRnsCrawler(url)
    profiles = crawler.crawl()
    
    crawler.save_profiles_to_csv(args.outfile)

    for profile in profiles:
        print(f"Downloading RDF for {profile['name']} from {profile['rdf_link']}")
        rdf_data = crawler.download_profile_rdf(profile['rdf_link'])
        if rdf_data:
            print(f"Successfully downloaded RDF for {profile['name']}")
            with open(profile['rdf_link'].split('/')[-1], "wb") as f:
                f.write(rdf_data)
        time.sleep(5)  # Sleep for 5 seconds between requests to avoid overwhelming the server

if __name__ == "__main__":
    main()