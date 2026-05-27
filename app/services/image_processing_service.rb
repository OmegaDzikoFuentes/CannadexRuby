# app/services/image_processing_service.rb
#
# Handles everything that needs to happen to a photo BEFORE it hits S3:
#   - EXIF extraction (GPS, device, capture time)
#   - Content type detection
#   - HEIC → JPEG conversion
#   - Thumbnail and medium variant generation
#   - Dimension extraction
#
# Dependencies: mini_magick, exifr, marcel (add to Gemfile)
#
# Usage:
#   result = ImageProcessingService.process(tempfile, original_filename: "bud.jpg")
#   result.original_path   # path to processed original
#   result.thumbnail_path  # path to thumbnail
#   result.medium_path     # path to medium
#   result.exif_data       # hash
#   result.content_type
#   result.dimensions      # { width: 3024, height: 4032 }
#   result.file_size       # bytes

require 'mini_magick'
require 'exifr/jpeg'
require 'exifr/tiff'

class ImageProcessingService
  class Error < StandardError; end
  class UnsupportedFormatError < Error; end
  class ProcessingError < Error; end

  # Output image settings
  THUMBNAIL_MAX  = 400    # px on longest side
  MEDIUM_MAX     = 1200   # px on longest side
  ORIGINAL_MAX   = 3000   # cap originals — prevents huge RAW-ish files
  JPEG_QUALITY   = 85
  STRIP_METADATA = false  # keep EXIF on originals; strip on variants

  Result = Struct.new(
    :original_path,
    :thumbnail_path,
    :medium_path,
    :content_type,
    :file_size,
    :width,
    :height,
    :exif_data,
    keyword_init: true
  ) do
    def dimensions = { width: width, height: height }
    def portrait?  = height > width
  end

  # -------------------------------------------------------------------------
  # Entry point
  # -------------------------------------------------------------------------

  def self.process(file_or_path, original_filename: nil)
    new(file_or_path, original_filename: original_filename).process
  end

  def initialize(file_or_path, original_filename: nil)
    @source_path      = resolve_path(file_or_path)
    @original_filename = original_filename
    @tempfiles         = []   # tracked so we can clean up on failure
  end

  def process
    content_type = detect_content_type

    # Convert HEIC/HEIF to JPEG first (MiniMagick handles this if libheif is installed)
    working_path = convert_heic_if_needed(@source_path, content_type)
    content_type = 'image/jpeg' if %w[image/heic image/heif].include?(content_type)

    image = MiniMagick::Image.open(working_path)

    validate_image!(image)

    exif      = extract_exif(working_path, content_type)
    original  = resize_and_save(image, max_dimension: ORIGINAL_MAX, strip: false)
    thumbnail = resize_and_save(image, max_dimension: THUMBNAIL_MAX, strip: true)
    medium    = resize_and_save(image, max_dimension: MEDIUM_MAX,    strip: true)

    Result.new(
      original_path:  original,
      thumbnail_path: thumbnail,
      medium_path:    medium,
      content_type:   content_type,
      file_size:      File.size(original),
      width:          image.width,
      height:         image.height,
      exif_data:      exif
    )
  rescue MiniMagick::Error => e
    raise ProcessingError, "Image processing failed: #{e.message}"
  end

  # -------------------------------------------------------------------------
  # Cleanup — call this after uploading to S3
  # -------------------------------------------------------------------------

  def self.cleanup(result)
    [result.original_path, result.thumbnail_path, result.medium_path].each do |path|
      File.unlink(path) if path && File.exist?(path)
    rescue Errno::ENOENT
      # Already gone — fine
    end
  end

  private

  # -------------------------------------------------------------------------
  # Processing steps
  # -------------------------------------------------------------------------

  def detect_content_type
    Marcel::MimeType.for(
      Pathname.new(@source_path),
      name: @original_filename
    ) || 'image/jpeg'
  end

  def convert_heic_if_needed(path, content_type)
    return path unless %w[image/heic image/heif].include?(content_type)

    out = tmp_path('.jpg')
    image = MiniMagick::Image.open(path)
    image.format('jpeg')
    image.write(out)
    out
  end

  def validate_image!(image)
    raise UnsupportedFormatError, "Not a valid image" unless image.valid?
    raise ProcessingError, "Image is too small (< 100px)" if image.width < 100 || image.height < 100
    raise ProcessingError, "Image is too large (> 50MP)" if image.width * image.height > 50_000_000
  end

  def resize_and_save(image, max_dimension:, strip: false)
    out    = tmp_path('.jpg')
    resized = image.clone

    # Resize only if larger than max (preserve aspect ratio)
    if [image.width, image.height].max > max_dimension
      resized.resize "#{max_dimension}x#{max_dimension}"
    end

    resized.strip if strip
    resized.quality JPEG_QUALITY.to_s
    resized.format 'jpeg'
    resized.write out
    out
  end

  def extract_exif(path, content_type)
    exif_hash = {}

    reader = case content_type
             when 'image/jpeg' then EXIFR::JPEG.new(path)
             when 'image/tiff' then EXIFR::TIFF.new(path)
             else return exif_hash
             end

    return exif_hash unless reader.exif?

    exif = reader.exif

    exif_hash[:make]               = exif.make&.strip
    exif_hash[:model]              = exif.model&.strip
    exif_hash[:software]           = exif.software&.strip
    exif_hash[:date_time_original] = exif.date_time_original&.to_s
    exif_hash[:exposure_time]      = exif.exposure_time&.to_s
    exif_hash[:f_number]           = exif.f_number&.to_f
    exif_hash[:iso]                = exif.iso_speed_ratings
    exif_hash[:focal_length]       = exif.focal_length&.to_f
    exif_hash[:flash]              = exif.flash&.fired?
    exif_hash[:orientation]        = exif.orientation&.to_i

    if reader.respond_to?(:gps) && reader.gps
      gps = reader.gps
      exif_hash[:gps_latitude]  = gps.latitude.round(6)
      exif_hash[:gps_longitude] = gps.longitude.round(6)
      exif_hash[:gps_altitude]  = gps.altitude&.round(2)
    end

    exif_hash.compact
  rescue => e
    Rails.logger.warn "[ImageProcessingService] EXIF extraction failed: #{e.message}"
    {}
  end

  def tmp_path(ext)
    path = Rails.root.join('tmp', "img_#{SecureRandom.hex(8)}#{ext}").to_s
    @tempfiles << path
    path
  end

  def resolve_path(file_or_path)
    case file_or_path
    when String, Pathname then file_or_path.to_s
    when Tempfile, File   then file_or_path.path
    else raise ArgumentError, "Expected path, File, or Tempfile"
    end
  end
end