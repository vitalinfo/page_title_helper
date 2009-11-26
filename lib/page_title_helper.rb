# PageTitleHelper provides an +ActionView+ helper method to simplify adding
# custom titles to pages.
#
# Author:: Lukas Westermann
# Copyright:: Copyright (c) 2009 Lukas Westermann (Zurich, Switzerland)
# Licence:: MIT-Licence (http://www.opensource.org/licenses/mit-license.php)
#
# See documentation for +page_title+ for usage examples and more informations.

# PageTitleHelper
module PageTitleHelper

  # http://github.com/thoughtbot/paperclip/blob/master/lib/paperclip/interpolations.rb
  module Interpolations
    # Represents the environment which is passed into each interpolation call.
    class TitleEnv < ::Struct.new(:options, :view, :controller, :title); end
    
    extend self
    
    def self.interpolate(pattern, *args)
      instance_methods(false).sort.reverse.inject(pattern.to_s.dup) do |result, tag|
        result.gsub(/:#{tag}/) do |match|
          send(tag, *args)
        end
      end
    end
    
    def app(env)
      env.options[:app] || I18n.translate(:'app.name', :default => File.basename(RAILS_ROOT).humanize)
    end
    
    def title(env)
      env.title
    end
  end
  
  # Add new, custom, interpolation.
  def self.interpolates(key, &block)
    Interpolations.send(:define_method, key, &block)
  end
  
  # Default options, which are globally referenced and can
  # be changed globally, which might be useful in some cases.
  def self.options
    @options ||= {
      :format => :default,
      :default => :'app.tagline',
      :suffix => :title
    }
  end
  
  # Defined alias formats, pretty useful.
  def self.formats
    @formats ||= {
      :app => ":app",
      :default => ':title - :app',
      :title => ":title"
    }
  end
  
  # Specify page title
  def page_title!(*args)
    @_page_title = args.size > 1 ? args : args.first
    @_page_title.is_a?(Array) ? @_page_title.first : @_page_title
  end
  
  def page_title(options = nil, &block)
    return page_title!(yield) if block_given? # define title
        
    options = PageTitleHelper.options.merge(options || {}).symbolize_keys!
    options[:format] ||= :title # handles :format => false
    options.assert_valid_keys(:app, :suffix, :default, :format)
    
    # construct basic env to pass around
    env = Interpolations::TitleEnv.new(options, self, self.controller)
    
    # read page title and split into 'real' title and customized format
    env.title = @_page_title || I18n.translate(i18n_template_key(options[:suffix]), :default => options[:default])
    env.title, options[:format] = *(env.title << options[:format]) if env.title.is_a?(Array)
    
    # handle format aliases
    format = options[:format]
    format = PageTitleHelper.formats[format] if PageTitleHelper.formats.include?(format)
    
    # interpolate format
    Interpolations.interpolate format, env
  end
  
  protected
  
    # Find current title key based on currently rendering template.
    #
    # Access +ActionView+s internal <tt>@_first_render</tt> variable, to access
    # template first rendered, this is to help create the DRY-I18n-titles magic,
    # and also kind of a hack, because this really seems to be some sort if
    # internal variable, that's why it's "abstracted" away as well.
    #
    # Also ensure that the extensions (like <tt>.html.erb</tt> or
    # <tt>.html.haml</tt>) have been stripped of and translated in the sense
    # of converting <tt>/</tt> to <tt>.</tt>.
    def i18n_template_key(suffix = nil)
      @_first_render.template_path.gsub(/\.[^\/]*\Z/, '').tr('/', '.') + (suffix.present? ? ".#{suffix}" : "")
    end
end