from bs4 import BeautifulSoup
import requests
import csv

class ProfilesRnsCrawler:

    page_size = 100
    total_pages = 0
    current_page = 1
    profiles = []

    def __init__(self, url):
        self.url = url

    def crawl(self):
        response = requests.get(self.url + str(self.current_page))
        if response.status_code == 200:
            soup = BeautifulSoup(response.content, 'html.parser')
            if self.total_pages == 0:
                self.total_pages = int(soup.find_all(id="txtTotalPages")[0].get('value'))

            # Extract relevant data from the soup object
            # For example, you can extract profile names, links, etc.
            
            for profile in soup.find_all('a', class_='listTableLink'):
                name = profile.contents[0].strip()
                link = profile['href']
                self.profiles.append({'name': name, 'link': link})
            
            while self.current_page < self.total_pages:
                self.current_page += 1
                response = requests.get(self.url + str(self.current_page))
                if response.status_code == 200:
                    soup = BeautifulSoup(response.content, 'html.parser')
                    for profile in soup.find_all('a', class_='listTableLink'):
                        name = profile.contents[0].strip()
                        link = profile['href']
                        self.profiles.append({'name': name, 'link': link})
                        print(f"Name: {name}, Link: {link}")
                else:
                    print(f"Failed to retrieve data from {self.url} on page {self.current_page}")
                    break

            return self.profiles
        else:
            print(f"Failed to retrieve data from {self.url}")
            return []
        
def main():
    #url = "https://profiles.uchicago.edu/profiles/search/default.aspx?searchtype=people&classuri=http://xmlns.com/foaf/0.1/Person&searchfor=&perpage=100&offset=0&page="
    url = "https://profiles.rush.edu/search/default.aspx?searchtype=people&classuri=http://xmlns.com/foaf/0.1/Person&searchfor=&perpage=100&offset=0&page="

    crawler = ProfilesRnsCrawler(url)
    profiles = crawler.crawl()
    for profile in profiles:
        print(f"Name: {profile['name']}, Link: {profile['link']}")
    keys = profiles[0].keys()

    with open('profiles_rush.csv', 'w', newline='') as output_file:
        dict_writer = csv.DictWriter(output_file, keys)
        dict_writer.writeheader()
        dict_writer.writerows(profiles)

if __name__ == "__main__":
    main()