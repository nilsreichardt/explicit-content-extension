Use this extension to automatically detect explicit content in images uploaded to Firebase Storage. The extension uses the [Google Cloud Vision API](https://cloud.google.com/vision) to detect explicit content in images uploaded to Firebase Storage. It then blurs the image and replaces the original image with the blurred version while retaining the original image's metadata.

Here's how it works:

1. The extension is triggered when a new image is uploaded to Firebase Storage.
2. Upon the image upload, a Cloud Function is triggered, which calls the Cloud Vision API to analyze the content of the image.
3. The Cloud Vision API determines whether the image contains explicit content or not.
4. If the image does contain explicit content, the extension takes several actions:
  a) The image is downloaded from Firebase Storage.
  b) The downloaded image is blurred and compressed to obscure the explicit content.
  c) The blurred image is then uploaded back to Firebase Storage, replacing the original image while retaining all metadata.
  d) A Firestore document is created to store details about the blurred image.
If the image does not contain explicit content, no further action is taken by the extension.

The extension automatically copies the following metadata, if present, from the original image to the resized image(s): `Cache-Control`, `Content-Disposition`, `Content-Encoding`, `Content-Language`, `Content-Type`, and user-provided metadata (the Firebase storage download token will also be copied).

Backfill is not supported. Only images uploaded after installing this extension will be processed.

#### Additional setup

Before installing this extension, make sure that you've [set up a Cloud Storage bucket](https://firebase.google.com/docs/storage) in your Firebase project.

> **NOTE**: As mentioned above, this extension listens for all changes made to the specified Cloud Storage bucket. This may cause unnecessary function calls. It is recommended to create a separate Cloud Storage bucket, especially for images you want to resize, and set up this extension to listen to that bucket.

#### Billing

To install an extension, your project must be on the [Blaze (pay as you go) plan](https://firebase.google.com/pricing)

- This extension uses other Firebase and Google Cloud Platform services, which have associated charges if you exceed the service’s no-cost tier:
 - Cloud Storage
 - Cloud Functions (Node.js 10+ runtime. [See FAQs](https://firebase.google.com/support/faq#extensions-pricing))
 - Cloud Vision API, Safe Search (explicit content) Detection (See [pricing](https://cloud.google.com/vision/pricing#prices))
