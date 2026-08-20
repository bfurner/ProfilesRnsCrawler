from bs4 import BeautifulSoup
import requests
import csv
import time
from pathlib import Path

class ProfilesRnsCrawler:


    def __init__(self, url):
        self.url = url
        self.page_size = 100
        self.total_pages = 0
        self.current_page = 1
        self.profiles = []

    def save_profiles_to_csv(self, filename):
        keys = self.profiles[0].keys()

        script_location = Path(__file__).absolute().parent
        file_location = script_location / filename.strip()

        with open(file_location, 'w', newline='') as output_file:
            dict_writer = csv.DictWriter(output_file, keys)
            dict_writer.writeheader()
            dict_writer.writerows(self.profiles)

    def crawl(self):
        max_retries = 3
        for attempt in range(max_retries):
            try:
                response = requests.get(self.url + str(self.current_page), timeout=60)
                response.raise_for_status()
                break
            except requests.RequestException as e:
                if attempt == max_retries - 1:
                    raise RuntimeError(
                        f"Failed to retrieve data from {self.url} "
                        f"on page {self.current_page}"
                    ) from e
                time.sleep(2 ** attempt)

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
            for attempt in range(max_retries):
                try:
                    response = requests.get(
                        self.url + str(self.current_page), timeout=60
                    )
                    response.raise_for_status()
                    break
                except requests.RequestException as e:
                    if attempt == max_retries - 1:
                        raise RuntimeError(
                            f"Failed to retrieve data from {self.url} "
                            f"on page {self.current_page}"
                        ) from e
                    time.sleep(2 ** attempt)

            soup = BeautifulSoup(response.content, 'html.parser')
            for profile in soup.find_all('a', class_='listTableLink'):
                name = profile.contents[0].strip()
                link = profile['href']
                rdf_link = profile['href'] + '/' + profile['href'].split('/')[-1] + '.rdf'
                self.profiles.append({'name': name, 'link': link, 'rdf_link': rdf_link})

        return self.profiles
