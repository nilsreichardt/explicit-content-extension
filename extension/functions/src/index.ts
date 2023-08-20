/*
 * This template contains a HTTP function that responds
 * with a greeting when called
 *
 * Reference PARAMETERS in your functions code with:
 * `process.env.<parameter-name>`
 * Learn more about building extensions in the docs:
 * https://firebase.google.com/docs/extensions/publishers
 */

import * as vision from "@google-cloud/vision";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import * as logger from "firebase-functions/logger";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import * as sharp from "sharp";
import {
  RemoteSafeSearchRepository,
  SafeSearchResult,
} from "./safe_search_repository";

// Initialize the Firebase Admin SDK
admin.initializeApp();

const bucketName = process.env.IMG_BUCKET!; // Example: explicit-content-extension.appspot.com
// const bucketName = "gs://explicit-content-extension.appspot.com/";
logger.info(`bucketName: ${bucketName}`);

export const generateResizedImageHandler = async (params: {
  name: string | undefined;
}): Promise<void> => {
  const filePath = `gs://${bucketName}/${params.name}`; // File path in the bucket.
  logger.info(`Received file: ${filePath}`);

  const safeSearchRepository = new RemoteSafeSearchRepository(
    new vision.ImageAnnotatorClient()
  );

  const result = await safeSearchRepository.requestImage(filePath);

  logger.info(`result: ${JSON.stringify(result)}`);

  if (hasExplicitContent(result)) {
    logger.info("Has explicit content!");
    await replaceImageWithBlur(params.name!);
    await addFirestoreDoc(result, params.name!);
  } else {
    logger.info("No explicit content detected...");
  }
};

async function addFirestoreDoc(result: SafeSearchResult, fileName: string) {
  const db = admin.firestore();
  await db.collection("ExplicitImages").add({
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    safeSearchAnnotation: result,
    bucketName: bucketName,
    fileName: fileName,
  });
  logger.info("Firestore doc added!");
}

// Blurs the given image located in the given bucket using ImageMagick.
async function replaceImageWithBlur(fileName: string) {
  const tempLocalFile = path.join(os.tmpdir(), path.basename(fileName));

  await downloadImage(fileName, tempLocalFile);
  const tempLocalOutputFile = `${tempLocalFile}-blurred`;
  await blur(tempLocalFile, tempLocalOutputFile);
  await uploadImage(tempLocalOutputFile, fileName);

  fs.unlinkSync(tempLocalFile);
  fs.unlinkSync(tempLocalOutputFile);

  logger.info(`Blurred image has been uploaded to ${fileName}`);
}

async function downloadImage(bucketPath: string, tempLocalFilePath: string) {
  const bucket = admin.storage().bucket(bucketName);
  await bucket.file(bucketPath).download({ destination: tempLocalFilePath });
  console.log("Image has been downloaded to", tempLocalFilePath);
}

async function blur(tempLocalFilePath: string, outputFilePath: string) {
  await sharp(tempLocalFilePath)
    .jpeg({ quality: 50 })
    .blur(100)
    .toFile(outputFilePath);
}

async function uploadImage(
  outputFilePath: string,
  bucketPath: string
): Promise<void> {
  const bucket = admin.storage().bucket(bucketName);
  const originalMetadata = (await bucket.file(bucketPath).getMetadata())[0];
  const originalCustomMetadata = originalMetadata.metadata ?? {};

  await bucket.upload(outputFilePath, {
    destination: bucketPath,
    metadata: {
      metadata: originalCustomMetadata,
      contentType: "image/jpeg",
      contentDisposition: originalMetadata.contentDisposition,
    },
  });

  console.log("Image has been uploaded to", bucketPath);
}

function hasExplicitContent(safeSearchResult: SafeSearchResult): boolean {
  const { LIKELY } = vision.protos.google.cloud.vision.v1.Likelihood;
  const { adult, medical, racy, spoof, violence } = safeSearchResult;
  return [adult, medical, racy, spoof, violence].some(
    (val) =>
      vision.protos.google.cloud.vision.v1.Likelihood[val] >= LIKELY
  );
}

export const explicitContentDetection = functions.storage
  .bucket(bucketName)
  .object()
  .onFinalize(async (object) => {
    await generateResizedImageHandler({
      name: object.name,
    });
  });
