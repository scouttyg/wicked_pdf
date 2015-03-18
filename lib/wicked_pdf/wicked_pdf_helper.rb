require 'open-uri'

module WickedPdfHelper
  def self.root_path
    String === Rails.root ? Pathname.new(Rails.root) : Rails.root
  end

  def self.add_extension(filename, extension)
    (File.extname(filename.to_s)[1..-1] == extension) ? filename : "#{filename}.#{extension}"
  end

  def wicked_pdf_stylesheet_link_tag(*sources)
    Rails.logger.info "Hey, I'm not being recognized"
    css_dir = WickedPdfHelper.root_path.join('public', 'stylesheets')
    css_text = sources.collect { |source|
      source = WickedPdfHelper.add_extension(source, 'css')
      "<style type='text/css'>#{File.read(css_dir.join(source))}</style>"
    }.join("\n")
    css_text.respond_to?(:html_safe) ? css_text.html_safe : css_text
  end

  def wicked_pdf_image_tag(img, options = {})
    image_tag "file:///#{WickedPdfHelper.root_path.join('public', 'images', img)}", options
  end

  def wicked_pdf_javascript_src_tag(jsfile, options = {})
    jsfile = WickedPdfHelper.add_extension(jsfile, 'js')
    src = "file:///#{WickedPdfHelper.root_path.join('public', 'javascripts', jsfile)}"
    content_tag('script', '', { 'type' => Mime::JS, 'src' => path_to_javascript(src) }.merge(options))
  end

  def wicked_pdf_javascript_include_tag(*sources)
    js_text = sources.collect { |source| wicked_pdf_javascript_src_tag(source, {}) }.join("\n")
    js_text.respond_to?(:html_safe) ? js_text.html_safe : js_text
  end

  module Assets
    ASSET_URL_REGEX = /url\(['"](.+)['"]\)(.+)/

    def wicked_pdf_stylesheet_link_tag(*sources)
      Rails.logger.info "Yay, I was recognized!!"
      stylesheet_contents = sources.collect do |source|
        source = WickedPdfHelper.add_extension(source, 'css')
        "<style type='text/css'>#{read_asset(source)}</style>"
      end.join('\n')

      stylesheet_contents.gsub(ASSET_URL_REGEX) do
        "url(#{wicked_pdf_asset_path($1)})#{$2}"
      end.html_safe
    end

    def wicked_pdf_image_tag(img, options = {})
      image_tag wicked_pdf_asset_path(img), options
    end

    def wicked_pdf_javascript_src_tag(jsfile, options = {})
      jsfile = WickedPdfHelper.add_extension(jsfile, 'js')
      javascript_include_tag wicked_pdf_asset_path(jsfile), options
    end

    def wicked_pdf_javascript_include_tag(*sources)
      sources.collect { |source|
        source = WickedPdfHelper.add_extension(source, 'js')
        "<script type='text/javascript'>#{read_asset(source)}</script>"
      }.join("\n").html_safe
    end

    def wicked_pdf_asset_path(asset)
      if (pathname = asset_pathname(asset).to_s) =~ URI_REGEXP
        pathname
      else
        "file:///#{pathname}"
      end
    end

    private

    # borrowed from actionpack/lib/action_view/helpers/asset_url_helper.rb
    URI_REGEXP = %r{^[-a-z]+://|^(?:cid|data):|^//}

    def asset_pathname(source)
      Rails.logger.info "I'm in asset_pathname"
      Rails.logger.info source
      if precompiled_asset?(source)
        Rails.logger.info "I'm again a precompiled asset"
        pathname = set_protocol(asset_path(source))
        Rails.logger.info "Asset url?"
        Rails.logger.info asset_path(source)
        Rails.logger.info "Pathname?"
        Rails.logger.info pathname
        Rails.logger.info "Pass regex?"
        Rails.logger.info pathname =~ URI_REGEXP
        if pathname =~ URI_REGEXP
          Rails.logger.info "I passed the regex!"
          # asset_path returns an absolute URL using asset_host if asset_host is set
          pathname
        else
          Rails.logger.info "Crap, I didn't pass the regex!"
          File.join(Rails.public_path, asset_path(source).sub(/\A#{Rails.application.config.action_controller.relative_url_root}/, ''))
        end
      else
        Rails.logger.info "Crap, I'm not a precompiled asset for some reason"
        Rails.application.assets.find_asset(source).pathname
      end
    end

    # will prepend a http or default_protocol to a protocol relative URL
    # or when no protcol is set.
    def set_protocol(source)
      Rails.logger.info "Now in set_protocol!"
      Rails.logger.info source
      protocol = WickedPdf.config[:default_protocol] || 'http'
      Rails.logger.info "Protocol?"
      Rails.logger.info protocol
      if source[0, 2] == '//'
        Rails.logger.info "In first if"
        source = [protocol, ':', source].join
      elsif !source[0, 8].include?('://')
        Rails.logger.info "In elseif"
        source = [protocol, '://', source].join
      end
      Rails.logger info "Final source"
      Rails.logger.info source
      source
    end

    def precompiled_asset?(source)
      Rails.configuration.assets.compile == false || source.to_s[0] == '/'
    end

    def read_asset(source)
      Rails.logger.info "Ok, I'm in read asset"
      if precompiled_asset?(source)
        Rails.logger.info "Ok, I'm a precompiled asset"
        if set_protocol(asset_path(source)) =~ URI_REGEXP
          Rails.logger.info "Source?"
          Rails.logger.info source
          read_from_uri(source)
        else
          IO.read(asset_pathname(source))
        end
      else
        Rails.logger.info "Not precompiled, crap"
        Rails.application.assets.find_asset(source).to_s
      end
    end

    def read_from_uri(source)
      Rails.logger.info "Im in the read_from_uri method!"
      Rails.logger.info source
      encoding = ':UTF-8' if RUBY_VERSION > '1.8'
      Rails.logger.info asset_pathname(source)
      asset = open(asset_pathname(source), "r#{encoding}") { |f| f.read }
      asset = gzip(asset) if WickedPdf.config[:expect_gzipped_remote_assets]
      asset
    end

    def gzip(asset)
      stringified_asset = StringIO.new(asset)
      gzipper = Zlib::GzipReader.new(stringified_asset)
      gzipped_asset = gzipper.read
    rescue Zlib::GzipFile::Error
    end

  end
end
