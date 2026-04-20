import csv
import io
import os
import re
import time
import uuid

import pytesseract
import requests
from PIL import Image, UnidentifiedImageError

CSV_FILE = os.getenv("CSV_FILE", "uchicago_emailencrypted_sample.csv")
OUTPUT_CSV_FILE = os.getenv("OUTPUT_CSV_FILE", "uchicago_extracted_emails.csv")
BASE_PROFILE_PREFIX = os.getenv(
    "BASE_PROFILE_PREFIX", "https://profiles.uchicago.edu/profiles/profile/"
)
EMAIL_HANDLER_URL = os.getenv(
    "EMAIL_HANDLER_URL",
    "https://profiles.uchicago.edu/profiles/profile/modules/"
    "CustomViewPersonGeneralInfo/EmailHandler.ashx",
)


def load_email_tokens(csv_file: str) -> dict[str, tuple]:
    """Load {profile_id: (full_row_dict, encrypted_token)} from CSV."""
    rows: dict[str, tuple] = {}
    with open(csv_file, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            person = (row.get("person") or "").strip()
            token = (row.get("emailencrypted") or "").strip()
            if not person or not token:
                continue
            key = person.replace(BASE_PROFILE_PREFIX, "")
            rows[key] = (row, token)
    return rows


def is_image_response(resp: requests.Response) -> bool:
    content_type = (resp.headers.get("Content-Type") or "").lower()
    return content_type.startswith("image/")


def cleanup_email_text(raw_text: str) -> str:
    """Normalize OCR output and return a cleaned email when possible."""
    normalized = raw_text.replace("\n", " ").replace("\r", " ").strip()
    normalized = re.sub(r"\s+", "", normalized)

    # Try to extract a valid email directly from OCR text.
    match = re.search(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}", normalized)
    if match:
        return match.group(0).rstrip("_.-")

    # Fallback cleanup when OCR is noisy but close.
    return normalized.rstrip("_.,;:-")


def main() -> None:
    email_tokens = load_email_tokens(CSV_FILE)
    results: dict[str, dict] = {}

    for key, (original_row, token) in email_tokens.items():
        print(f"Processing {key}")

        try:
            # New session per request as requested.
            with requests.Session() as session:
                response = session.get(
                    EMAIL_HANDLER_URL,
                    params={"msg": token, "rnd": str(uuid.uuid4())},
                    timeout=20,
                    allow_redirects=True,
                    headers={
                        "User-Agent": "Mozilla/5.0",
                        "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
                    },
                )
                response.raise_for_status()

            if not is_image_response(response):
                print(
                    f"Skipped {key}: non-image response "
                    f"(Content-Type={response.headers.get('Content-Type')})"
                )
                results[key] = {**original_row, "extracted_email": ""}
                time.sleep(1)
                continue

            img_path = f"{key}_email_image.png"
            with open(img_path, "wb") as f:
                f.write(response.content)

            # Open from bytes first so we can fail fast on invalid files.
            image = Image.open(io.BytesIO(response.content))
            email_text = cleanup_email_text(pytesseract.image_to_string(image))
            results[key] = {**original_row, "extracted_email": email_text}
            print(f"Extracted email for {key}: {email_text}")

        except requests.RequestException as e:
            print(f"Request error for {key}: {e}")
            results[key] = {**original_row, "extracted_email": ""}
        except UnidentifiedImageError:
            print(f"Invalid image for {key}: response is not a readable image")
            results[key] = {**original_row, "extracted_email": ""}
        except Exception as e:  # noqa: BLE001
            print(f"Unexpected error for {key}: {e}")
            results[key] = {**original_row, "extracted_email": ""}
        finally:
            if img_path and os.path.exists(img_path):
                os.remove(img_path)

            # Pause between requests to be polite to the server.
            time.sleep(1)

    if results:
        fieldnames = list(results[next(iter(results))].keys())
        if "extracted_email" not in fieldnames:
            fieldnames.append("extracted_email")

        with open(OUTPUT_CSV_FILE, "w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for row_dict in results.values():
                writer.writerow(row_dict)

    print(f"Saved CSV output to: {OUTPUT_CSV_FILE}")
    print(f"Processed {len(results)} records.")


if __name__ == "__main__":
    main()

# Example image
# <img id="42444418-4c14-49e9-b7d5-fb89468313f4" src="https://profiles.uchicago.edu/profiles/profile/modules/CustomViewPersonGeneralInfo/EmailHandler.ashx?msg=xWNla6kUDenbsW9naE%2ft8mL1sc65%2fA%3d%3d&amp;rnd=42444418-4c14-49e9-b7d5-fb89468313f4" alt="" />
# Download the email image
# email_img_url = "https://profiles.uchicago.edu/profiles/profile/modules/CustomViewPersonGeneralInfo/EmailHandler.ashx?msg=xWNla6kUDenbsW9naE%2ft8mL1sc65%2fA%3d%3d&rnd=42444418-4c14-49e9-b7d5-fb89468313f4"
# email_img_url = "https://profiles.uchicago.edu/profiles/profile/modules/CustomViewPersonGeneralInfo/EmailHandler.ashx?msg=xGpsDaccHODdsW9naE%2ft8mL1sc65%2fA%3d%3d&amp;rnd=dd29616f-d069-4680-913e-aba58bfcd959"
# email_img_url = "https://profiles.uchicago.edu/profiles/profile/modules/CustomViewPersonGeneralInfo/EmailHandler.ashx?msg=xGpsDaccHODdsW9naE%2ft8mL1sc65%2fA%3d%3d"
# email_img_response = requests.get(email_img_url)
# with open("email_image.png", "wb") as f:
#     f.write(email_img_response.content)
# # Now use pytesseract to extract text from the image
# email_text = pytesseract.image_to_string(Image.open("email_image.png"))
# print("Extracted email:", email_text.strip())