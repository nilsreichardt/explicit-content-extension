import { generateResizedImageHandler } from "../src";

async function main(): Promise<void> {
  const fileName = "adult-content-edit.png";
  await generateResizedImageHandler({
    name: fileName,
  });
  return;
}

main();
