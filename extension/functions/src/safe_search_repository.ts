import * as vision from "@google-cloud/vision";
import * as logger from "firebase-functions/logger";

export abstract class SafeSearchRepository {
  abstract requestImage(downloadUrl: string): Promise<SafeSearchResult>;
}

export interface SafeSearchResult {
  adult: SafeSearchClassification;
  medical: SafeSearchClassification;
  racy: SafeSearchClassification;
  spoof: SafeSearchClassification;
  violence: SafeSearchClassification;
}

export type SafeSearchClassification =
  | "UNKNOWN"
  | "VERY_UNLIKELY"
  | "UNLIKELY"
  | "LIKELY"
  | "VERY_LIKELY"
  | "POSSIBLE";

/**
 * How to authenticate the client? There are serval ways. We just export the
 * service account credentials to the environment variables, because cloud
 * functions working with the same way.
 */
export class RemoteSafeSearchRepository extends SafeSearchRepository {
  constructor(private vision: vision.ImageAnnotatorClient) {
    super();
  }

  async requestImage(downloadUrl: string): Promise<SafeSearchResult> {
    const result = await this.vision.safeSearchDetection({
      image: { source: { imageUri: downloadUrl } },
    });
    logger.debug({
      message: `Received result from vision.safeSearchDetection`,
      response: result,
    });
    const safeSearchResults = result[0]["safeSearchAnnotation"];
    return {
      adult: safeSearchResults?.adult! as SafeSearchClassification,
      medical: safeSearchResults?.medical! as SafeSearchClassification,
      racy: safeSearchResults?.racy! as SafeSearchClassification,
      spoof: safeSearchResults?.spoof! as SafeSearchClassification,
      violence: safeSearchResults?.violence! as SafeSearchClassification,
    };
  }
}

export class MockSafeSearchRepository extends SafeSearchRepository {
  private imageResults: Map<string, SafeSearchResult> = new Map();

  setMockResult(downloadUrl: string, result: SafeSearchResult) {
    this.imageResults.set(downloadUrl, result);
  }

  async requestImage(downloadUrl: string): Promise<SafeSearchResult> {
    const result = this.imageResults.get(downloadUrl);
    if (!result) {
      throw Error(`Set first the mock result with before calling this method.`);
    }
    return result;
  }
}
