module AssetSyncDownload
  class << self

    def storage
      @storage ||= Storage.new
    end

    def download(target = :asset_files)
      AssetSync.with_config do
        self.storage.download(target)
      end
    end

    def webpacker_enabled?
      !!defined?(Webpacker)
    end
  end
end
