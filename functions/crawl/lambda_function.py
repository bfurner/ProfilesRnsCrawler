from ProfilesRnsCrawler import ProfilesRnsCrawler

def lambda_handler(event, context):
    crawler = ProfilesRnsCrawler(event['url'])
    profiles = crawler.crawl()
    
    return {
        "profiles": profiles
    }
