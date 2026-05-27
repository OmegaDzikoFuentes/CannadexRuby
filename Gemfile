source "https://rubygems.org"
 
# ── Rails core ────────────────────────────────────────────────────────────────
gem "rails", "~> 8.0.2"
gem "propshaft"                          # Modern asset pipeline
gem "puma", ">= 5.0"                     # Web server
 
# ── Frontend ──────────────────────────────────────────────────────────────────
gem "importmap-rails"
gem "turbo-rails"
gem "hotwire-rails"
gem "stimulus-rails"
gem "jbuilder"                           # JSON views
 
# ── Database ──────────────────────────────────────────────────────────────────
gem "pg", "~> 1.1"                       # PostgreSQL adapter
gem "activerecord-postgis-adapter"       # PostGIS (geography columns, ST_DWithin, etc.)
gem "rgeo-geojson"                       # GeoJSON support for location serialization
 
# ── Auth & Security ───────────────────────────────────────────────────────────
gem "bcrypt", "~> 3.1.7"                 # has_secure_password
gem "cancancan", "~> 3.6"               # Authorization (Ability class)
gem "jwt"                                # JWT tokens for API auth
gem "rack-cors"                          # CORS headers for mobile API clients
 
# ── File Storage — AWS S3 ─────────────────────────────────────────────────────
gem "aws-sdk-s3", "~> 1.170"            # S3 client — S3Service + Active Storage
gem "image_processing", "~> 1.2"        # Active Storage variants (avatars, strain images)
gem "mini_magick", "~> 4.12"            # ImageMagick wrapper — resize, convert, HEIC→JPEG
                                         # ⚠️  Requires imagemagick on the system:
                                         #   macOS:  brew install imagemagick libheif
                                         #   Ubuntu: apt-get install -y imagemagick libheif-dev
gem "marcel", "~> 1.0"                  # MIME type detection (already a Rails transitive dep,
                                         # pinning explicitly for S3Service content-type detection)
gem "exifr", "~> 1.4"                   # EXIF extraction from JPEG/TIFF (GPS, device, capture time)
 
# ── AI / Machine Learning ─────────────────────────────────────────────────────
gem "ruby-openai", "~> 7.0"             # GPT-4o Vision — AiIdentificationService
                                         # ⚠️  Set OPENAI_API_KEY in credentials:
                                         #   rails credentials:edit → openai: { api_key: sk-... }
 
# ── Background Jobs ───────────────────────────────────────────────────────────
# IMPORTANT: You currently have solid_queue AND sidekiq.
# solid_queue is Rails 8's built-in job backend (DB-backed, no Redis needed).
# sidekiq is Redis-backed and better for high-throughput async work like AI analysis.
#
# Recommendation: use Sidekiq for the AI/photo pipeline (latency-sensitive),
# keep solid_queue for everything else (mailers, achievements, card generation).
# You can configure this per-queue in config/application.rb.
# See: https://guides.rubyonrails.org/active_job_basics.html#multiple-backends
#
gem "sidekiq", "~> 7.3"                 # AI analysis queue (AnalyzePhotoJob)
gem "sidekiq-scheduler", "~> 5.0"       # Cron jobs (URL refresh, cleanup, orphan detection)
gem "redis", "~> 5.0"                   # Required by Sidekiq
                                         # ⚠️  Set REDIS_URL in env or credentials
 
# ── Rails 8 built-in backends (keep for non-AI jobs) ─────────────────────────
gem "solid_queue"                        # Default ActiveJob backend (mailers, achievements)
gem "solid_cache"                        # DB-backed Rails.cache
gem "solid_cable"                        # DB-backed Action Cable
 
# ── API & Networking ──────────────────────────────────────────────────────────
gem "httparty"                           # HTTP client (geocoding APIs, external lookups)
gem "kaminari"                           # Pagination for catalog/feed endpoints
 
# ── Digital Card Generation ───────────────────────────────────────────────────
gem "grover"                             # HTML → image/PDF via Puppeteer (encounter cards)
                                         # ⚠️  Requires Node.js + puppeteer:
                                         #   npm install puppeteer
 
# ── Platform support ──────────────────────────────────────────────────────────
gem "tzinfo-data", platforms: %i[windows jruby]
gem "bootsnap", ">= 1.4.4", require: false  # Faster boot via caching
 
# ── Deployment ────────────────────────────────────────────────────────────────
gem "kamal", require: false              # Docker-based deployment
gem "thruster", require: false           # HTTP caching + compression layer for Puma
 
# ─────────────────────────────────────────────────────────────────────────────
group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false         # Security static analysis
  gem "rubocop-rails-omakase", require: false
 
  # Testing
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "database_cleaner-active_record"
 
  # Test doubles for S3 / OpenAI (avoid real API calls in tests)
  gem "webmock", "~> 3.23"              # Stub HTTP requests (OpenAI, geocoding)
  gem "aws-sdk-core", "~> 3.0"          # Already a dep — stub_responses: true in tests
end
 
group :development do
  gem "listen", "~> 3.3"
  gem "spring"
  gem "annotate"                         # Auto-annotate models with schema
  gem "bullet"                           # N+1 query detection
 
  # Useful additions for this stack
  gem "rack-mini-profiler"               # Request profiling (catch slow queries)
  gem "memory_profiler"                  # Memory profiling (image processing can be hungry)
end
 
group :test do
  gem "shoulda-matchers", "~> 6.0"      # One-liner model/association matchers
  gem "timecop", "~> 0.9"               # Freeze time for XP/level/achievement tests
end
 