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
  module Interpolations
    # Represents the environment which is passed into each interpolation call.
    class Env < Struct.new(:options, :view, :controller, :title); end
    
    extend self
    
    def self.interpolate(pattern, *args)
      instance_methods(false).sort.reverse.inject(pattern.dup) do |result, tag|
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
      :format => ':app - :title',
      :default => :'app.tagline',
      :suffix => :title
    }
  end
  
  def page_title(options = nil, &block)
    if block_given? # define title
      content_for(:page_title) { yield }
      return read_page_title_content_block
    end
        
    options = PageTitleHelper.options.merge(options || {}).symbolize_keys!
    options[:format] ||= ":title" # to handle :format => false
    options.assert_valid_keys(:app, :suffix, :default, :format)
    
    # construct basic env to pass around
    env = Interpolations::Env.new(options, self, self.controller)
    
    # read page title
    env.title = read_page_title_content_block || I18n.translate(i18n_template_key(options[:suffix]), :default => options[:default])
  
    # interpolate, if :format => :app, just interpolate ':app', neat :)
    Interpolations.interpolate options[:format] == :app ? ':app' : options[:format], env
  end
  
  protected
    
    # Access <tt>@content_for_page_title</tt> variable, though this is a tad
    # hacky, because... what if they (the rails guys) change the behaviour of
    # <tt>content_for</tt>? Well, in Rails 2.3.x it works so far.
    #
    # But to simplify compatibility with later versions, this method kinda abstracts
    # away access to the content within a <tt>content_for</tt> block.
    def read_page_title_content_block
      instance_variable_get(:'@content_for_page_title')
    end
    
    # Access +ActionView+s internal <tt>@_first_render</tt> variable, to access
    # template first rendered, this is to help create the DRY-I18n-titles magic,
    # and also kind of a hack, because this really seems to be some sort if
    # internal variable, that's why it's "abstracted" away as well.
    #
    # Also ensure that the extensions (like <tt>.html.erb</tt> or
    # <tt>.html.haml</tt>) have been stripped of.
    def first_render_path_without_extension
      p = @_first_render.template_path
      p[0,p.index('.')]
    end
    
    def i18n_template_key(suffix = nil)
      ikey = first_render_path_without_extension.tr('/', '.')
      ikey = ikey + "." + suffix.to_s if suffix.present?
      ikey
    end
end

# tie stuff together
if Object.const_defined?('ActionView')
  ActionView::Base.send(:include, PageTitleHelper)
end