import os
try:
    from PIL import Image
except ImportError:
    print("Error: Pillow library is not installed. Please run 'pip install Pillow'")
    exit(1)

def convert_png_to_webp(source_dir, target_dir=None):
    if target_dir is None:
        target_dir = source_dir
    
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)

    for filename in os.listdir(source_dir):
        if filename.endswith(".png"):
            png_path = os.path.join(source_dir, filename)
            webp_filename = filename.replace(".png", ".webp")
            webp_path = os.path.join(target_dir, webp_filename)
            
            print(f"Converting {filename} to {webp_filename}...")
            try:
                with Image.open(png_path) as img:
                    img.save(webp_path, "WEBP", quality=80)
                print(f"Successfully saved to {webp_path}")
            except Exception as e:
                print(f"Failed to convert {filename}: {e}")

if __name__ == "__main__":
    # 프로젝트 루트 기준 경로 설정
    base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    assets_images_path = os.path.join(base_path, "assets", "images")
    
    # 변환된 파일을 저장할 임시 디렉토리 (또는 같은 디렉토리)
    # GitHub Pages에 올릴 준비를 위해 별도 폴더에 저장하는 것을 추천합니다.
    output_path = os.path.join(base_path, "assets", "webp_images")
    
    print(f"Source: {assets_images_path}")
    print(f"Output: {output_path}")
    
    convert_png_to_webp(assets_images_path, output_path)
    print("\nAll conversions completed.")
    print("Now you can upload the contents of 'assets/webp_images' to your GitHub Pages repository.")
