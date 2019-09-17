module AssetSyncDownload
  class Storage
    extend Forwardable

    LEGACY_MANIFEST_RE = /^manifest(-[0-9a-f]{32})?.json$/

    def_delegator :storage, :bucket
    def_delegator :storage, :config
    def_delegator :storage, :get_remote_files
    def_delegator :storage, :log
    def_delegator :storage, :path

    def storage
      @storage ||= AssetSync.storage
    end

    def get_asset_files_from_manifest
      if storage.respond_to?(:get_asset_files_from_manifest)
        return storage.get_asset_files_from_manifest
      end

      if self.config.manifest
        if ActionView::Base.respond_to?(:assets_manifest)
          log "Using: Rails 4.0 manifest access"
          manifest = Sprockets::Manifest.new(ActionView::Base.assets_manifest.environment, ActionView::Base.assets_manifest.dir)
          return manifest.assets.values.map { |f| File.join(self.config.assets_prefix, f) }
        elsif File.exist?(self.config.manifest_path)
          log "Using: Manifest #{self.config.manifest_path}"
          yml = YAML.load(IO.read(self.config.manifest_path))

          return yml.map do |original, compiled|
            # Upload font originals and compiled
            if original =~ /^.+(eot|svg|ttf|woff)$/
              [original, compiled]
            else
              compiled
            end
          end.flatten.map { |f| File.join(self.config.assets_prefix, f) }.uniq!
        else
          log "Warning: Manifest could not be found"
        end
      end
    end

    def extract_paths_from_manifest(manifest)
      manifest.values.map { |v| v.is_a?(Hash) ? extract_paths_from_manifest(v) : v }.flatten
    end

    def get_asset_files_from_webpacker_manifest
      if self.config.manifest
        entries = JSON.parse(Webpacker.config.public_manifest_path.read)
        extract_paths_from_manifest(entries).uniq.map { |f| f.sub(/^\//, '') }
      end
    end

    def download_manifest
      manifest_key = sprockets_manifest_key
      raise "Could not find any manifests. aborted." if manifest_key.nil?

      download_file(manifest_key, false)
    end

    def sprockets_manifest_key
      files = get_remote_files

      if Rails.application.config.assets.manifest
        manifest_key = files.find { |f| File.basename(f) == File.basename(Rails.application.config.assets.manifest) }
      elsif defined?(Sprockets::ManifestUtils)
        manifest_key = files.find { |f| File.basename(f) =~ Sprockets::ManifestUtils::MANIFEST_RE }
        manifest_key ||= files.find { |f| File.basename(f) =~ Sprockets::ManifestUtils::LEGACY_MANIFEST_RE }
      else
        manifest_key = files.find { |f| File.basename(f) =~ LEGACY_MANIFEST_RE }
      end

      manifest_key
    end

    def download_webpacker_manifest
      return unless AssetSyncDownload.webpacker_enabled?

      manifest_key = webpacker_manifest_key
      raise "Could not find any manifests. aborted." if manifest_key.nil?

      download_file(manifest_key, false)
    end

    def webpacker_manifest_key
      get_remote_files.find do |f|
        File.basename(f) == File.basename(Webpacker.config.public_manifest_path)
      end
    end

    def download_asset_files
      asset_paths = get_asset_files_from_manifest
      if asset_paths.nil?
        log "Using: Remote Directory Search"
        asset_paths = get_remote_files
      end

      asset_paths_with_gzipped(asset_paths).each do |asset_path|
        download_file(asset_path)
      end
    end

    def download_webpacker_asset_files
      return unless AssetSyncDownload.webpacker_enabled?

      asset_paths = get_asset_files_from_webpacker_manifest
      if asset_paths.nil?
        log "Using: Remote Directory Search"
        asset_paths = get_remote_files
      end

      asset_paths_with_gzipped(asset_paths).each do |asset_path|
        download_file(asset_path)
      end
    end

    def asset_paths_with_gzipped(asset_paths)
      files = get_remote_files

      asset_paths.map do |path|
        to_download = [path]
        to_download << "#{path}.gz" if files.include?("#{path}.gz")
        to_download
      end.flatten
    end

    def download_file(file_path, skip_if_existent = true)
      local_path = File.join(path, file_path)
      if skip_if_existent && File.exists?(local_path)
        log "Skipped: #{file_path}"
        return
      end

      file = bucket.files.get(file_path)

      local_dir = File.dirname(local_path)
      FileUtils.mkdir_p(local_dir) unless File.directory?(local_dir)
      File.open(local_path, "wb") { |f| f.write(file.body) }

      log "Downloaded: #{file_path} (#{file.content_length} Bytes)"
    end

    def download(target = :asset_files)
      log "AssetSync: Downloading #{target}."
      case target
      when :manifest
        download_manifest
      when :asset_files
        download_asset_files
      when :webpacker_manifest
        download_webpacker_manifest
      when :webpacker_asset_files
        download_webpacker_asset_files
      else
        raise "Unknown target specified: #{target}. It must be one of :manifest, :asset_files, :webpacker_manifest, :webpacker_asset_files"
      end
      log "AssetSync: Done."
    end
  end
end
