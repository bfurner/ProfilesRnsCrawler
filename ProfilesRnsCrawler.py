from bs4 import BeautifulSoup
import requests
import csv
from pathlib import Path

class ProfilesRnsCrawler:

    page_size = 100
    total_pages = 0
    current_page = 1
    profiles = []

    def __init__(self, url):
        self.url = url

    def save_profiles_to_csv(self, filename):
        keys = self.profiles[0].keys()

        script_location = Path(__file__).absolute().parent
        file_location = script_location / filename.strip()

        with open(file_location, 'w', newline='') as output_file:
            dict_writer = csv.DictWriter(output_file, keys)
            dict_writer.writeheader()
            dict_writer.writerows(self.profiles)

    def crawl(self):
        response = requests.get(self.url + str(self.current_page))
        if response.status_code == 200:
            soup = BeautifulSoup(response.content, 'html.parser')

            # Set total_pages if it hasn't been set yet
            if self.total_pages == 0:
                self.total_pages = int(soup.find_all(id="txtTotalPages")[0].get('value'))

            # Extract profiles from the first page and add them to the list
            for profile in soup.find_all('a', class_='listTableLink'):
                name = profile.contents[0].strip()
                link = profile['href']
                rdf_link = profile['href'] + '/' + profile['href'].split('/')[-1] + '.rdf'
                self.profiles.append({'name': name, 'link': link, 'rdf_link': rdf_link})
            
            # Continue crawling through the remaining pages
            while self.current_page < self.total_pages:
                self.current_page += 1
                response = requests.get(self.url + str(self.current_page))
                if response.status_code == 200:
                    soup = BeautifulSoup(response.content, 'html.parser')
                    for profile in soup.find_all('a', class_='listTableLink'):
                        name = profile.contents[0].strip()
                        link = profile['href']
                        rdf_link = profile['href'] + '/' + profile['href'].split('/')[-1] + '.rdf'
                        self.profiles.append({'name': name, 'link': link, 'rdf_link': rdf_link})
                else:
                    print(f"Failed to retrieve data from {self.url} on page {self.current_page}")
                    break

            return self.profiles
        else:
            print(f"Failed to retrieve data from {self.url}")
            return []

    def download_profile_rdf(self, profile_url):
        response = requests.get(profile_url)
        if response.status_code == 200:
            return response.content
        else:
            print(f"Failed to retrieve data from {profile_url}")
            return ""
