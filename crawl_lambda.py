from ProfilesRnsCrawler import ProfilesRnsCrawler

def handler(event, context):
    crawler = ProfilesRnsCrawler(event['url'])
    profiles = crawler.crawl()
    
    return {
        "profiles": profiles
    }
