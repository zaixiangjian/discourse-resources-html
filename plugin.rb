# name: discourse-resources-html
# about: 独立 HTML 资源/赞助商页面，支持后台 Markdown 配置
# version: 1.0.0
# authors: Hermes Agent
# url: https://github.com/your-username/discourse-resources-html

# frozen_string_literal: true

enabled_site_setting :resources_html_enabled

module ::DiscourseResourcesHtml
  PLUGIN_NAME = "discourse-resources-html"
end

require_relative "lib/discourse_resources_html/engine"

after_initialize do
  require_relative "app/controllers/discourse_resources_html/resources_controller"

  Discourse::Application.routes.append do
    mount ::DiscourseResourcesHtml::Engine, at: "/summary"
  end
end
