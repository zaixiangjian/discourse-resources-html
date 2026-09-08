# frozen_string_literal: true

require "cgi"

module DiscourseResourcesHtml
  class ResourcesController < ::ApplicationController
    skip_before_action :preload_json, raise: false
    skip_before_action :check_xhr, raise: false
    skip_before_action :redirect_to_login_if_required, raise: false

    def show
      raise Discourse::NotFound unless SiteSetting.resources_html_enabled?

      response.headers["X-Robots-Tag"] = "noindex, nofollow, noarchive, nosnippet"
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Content-Type-Options"] = "nosniff"

      render html: build_html.html_safe, layout: false, content_type: "text/html"
    end

    private

    def build_html
      sections = parse_content(SiteSetting.resources_html_content)
      footer_html = render_footer(SiteSetting.resources_html_footer_content)
      title = sections.first&.dig(:title).presence || "资源导航"
      logo_url = SiteSetting.respond_to?(:site_logo_url) ? SiteSetting.site_logo_url : nil
      logo_url = Discourse.base_url + SiteSetting.logo.url if logo_url.blank? && SiteSetting.respond_to?(:logo) && SiteSetting.logo&.url.present?
      logo_html = logo_url.present? ? %(<img src="#{h logo_url}" alt="#{h SiteSetting.title}" class="site-logo">) : h(SiteSetting.title)
      columns = [[SiteSetting.resources_html_columns.to_i, 1].max, 3].min
      font_size = [[SiteSetting.resources_html_font_size.to_i, 10].max, 24].min

      <<~HTML
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="robots" content="noindex,nofollow,noarchive,nosnippet">
          <meta name="referrer" content="no-referrer">
          <title>#{h title} - #{h SiteSetting.title}</title>
          <style>#{css(font_size)}</style>
        </head>
        <body>
          <header class="site-header">
            <a class="logo-link" href="#{h Discourse.base_url}/">#{logo_html}</a>
          </header>
          <main class="page" style="--columns: #{columns};">
            #{render_sections(sections)}
          </main>
          #{footer_html}
        </body>
        </html>
      HTML
    end

    def parse_content(content)
      sections = []
      current_section = nil
      current_item = nil

      content.to_s.gsub("\r\n", "\n").split("\n").each do |line|
        text = line.strip
        next if text.blank?

        if text.start_with?("# ")
          current_section = { title: text.sub(/\A#\s+/, "").strip, items: [] }
          sections << current_section
          current_item = nil
          next
        end

        if text.start_with?("## ")
          current_section ||= { title: "其他", items: [] }.tap { |section| sections << section }
          title = text.sub(/\A##\s+/, "").strip
          is_forum_user = title.start_with?("@")
          username = is_forum_user ? title.sub(/\A@/, "").strip : ""
          current_item = { title: title, username: username, forum_user: is_forum_user, website: "", description: [] }
          current_section[:items] << current_item if title.present?
          next
        end

        next if current_item.blank?

        if text.match?(/\A官网\s*[:：]/)
          current_item[:website] = text.sub(/\A官网\s*[:：]\s*/, "").strip
        elsif text.match?(/\A说明\s*[:：]/)
          current_item[:description] << text.sub(/\A说明\s*[:：]\s*/, "").strip
        else
          current_item[:description] << text
        end
      end

      sections
    end

    def render_sections(sections)
      return %(<section class="section"><h1>资源导航</h1><p class="empty">暂无内容</p></section>) if sections.blank?

      sections.map do |section|
        items_html = if section[:items].blank?
          %(<p class="empty">暂无内容</p>)
        else
          %(<div class="grid">#{section[:items].map { |item| render_item(item) }.join}</div>)
        end

        %(<section class="section"><h1>#{h section[:title]}</h1>#{items_html}</section>)
      end.join
    end

    def render_item(item)
      title = item[:title].to_s.strip
      username = item[:username].to_s.strip
      return "" if title.blank?

      website = safe_website(item[:website])
      website_html = website.present? ? %(<a class="website" href="#{h website}" target="_blank" rel="noopener nofollow noreferrer" referrerpolicy="no-referrer">官网</a>) : ""
      description = item[:description].join("\n").strip
      description_html = description.present? ? %(<div class="description">#{h description}</div>) : ""
      title_html = if item[:forum_user] && username.present?
        profile = "#{Discourse.base_url}/u/#{CGI.escape(username)}"
        %(<a class="username" href="#{h profile}" target="_blank" rel="noopener nofollow noreferrer">@#{h username}</a>)
      else
        %(<span class="username resource-title">#{h title}</span>)
      end

      <<~HTML
        <article class="card">
          <div class="card-top">
            #{title_html}
            #{website_html}
          </div>
          #{description_html}
        </article>
      HTML
    end

    def render_footer(content)
      parts = content.to_s.gsub("\r\n", "\n").split("\n").map(&:strip).reject(&:blank?)
      return "" if parts.blank?

      items = parts.map { |part| render_footer_part(part) }.reject(&:blank?)
      return "" if items.blank?

      %(<footer class="site-footer">#{items.join}</footer>)
    end

    def render_footer_part(text)
      value = text.to_s.strip

      if (match = value.match(/\A\[([^\]]+)\]\(([^)]+)\)\z/))
        label = match[1].strip
        url = safe_footer_url(match[2])
        return "" if label.blank? || url.blank?

        if url.downcase.start_with?("mailto:")
          return %(<a href="#{h url}" rel="noopener nofollow noreferrer">#{h label}</a>)
        end

        return %(<a href="#{h url}" target="_blank" rel="noopener nofollow noreferrer" referrerpolicy="no-referrer">#{h label}</a>)
      end

      %(<span>#{h value}</span>)
    end

    def safe_footer_url(url)
      value = url.to_s.strip
      return "" unless value.match?(/\A(?:https?:\/\/|mailto:)/i)
      value
    end

    def safe_website(url)
      value = url.to_s.strip
      return "" unless value.match?(/\Ahttps?:\/\//i)
      value
    end

    def h(value)
      ERB::Util.html_escape(value.to_s)
    end

    def css(font_size)
      <<~CSS
        :root { color-scheme: light dark; }
        * { box-sizing: border-box; }
        body {
          margin: 0;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans SC", "Microsoft YaHei", sans-serif;
          background: #f7f8fb;
          color: #1f2937;
        }
        .site-header {
          position: sticky;
          top: 0;
          z-index: 100;
          height: 64px;
          display: flex;
          align-items: center;
          padding: 0 28px;
          background: #fff;
          border-bottom: 1px solid #e5e7eb;
          box-shadow: 0 2px 10px rgba(15, 23, 42, .04);
        }
        .logo-link { display: inline-flex; align-items: center; color: inherit; text-decoration: none; font-size: 22px; font-weight: 800; }
        .site-logo { max-height: 38px; max-width: 210px; object-fit: contain; }
        .page { max-width: 1080px; margin: 0 auto; padding: 32px 18px 56px; }
        .section { margin-bottom: 38px; }
        .section h1 {
          margin: 0 0 18px;
          padding-bottom: 10px;
          font-size: 28px;
          line-height: 1.25;
          border-bottom: 1px solid #e5e7eb;
        }
        .grid { display: grid; grid-template-columns: repeat(var(--columns), minmax(0, 1fr)); gap: 16px; }
        .card {
          padding: 15px 16px;
          border: 1px solid #e5e7eb;
          border-radius: 14px;
          background: #fff;
          box-shadow: 0 8px 24px rgba(15, 23, 42, .06);
        }
        .card-top { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 8px; }
        .username { min-width: 0; overflow-wrap: anywhere; color: #2563eb; font-size: #{font_size + 3}px; font-weight: 800; text-decoration: none; }
        .username:hover { text-decoration: underline; }
        .resource-title { color: #374151; cursor: default; }
        .resource-title:hover { text-decoration: none; }
        .website {
          flex: 0 0 auto;
          padding: 3px 9px;
          border-radius: 999px;
          color: #0f766e;
          background: #ccfbf1;
          font-size: #{[font_size - 1, 10].max}px;
          font-weight: 800;
          text-decoration: none;
        }
        .website:hover { color: #fff; background: #0f766e; }
        .description { white-space: pre-line; color: #4b5563; font-size: #{font_size}px; line-height: 1.6; }
        .empty { margin: 0; color: #6b7280; }
        .site-footer {
          max-width: 1080px;
          margin: 0 auto;
          padding: 18px 18px 30px;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 12px;
          flex-wrap: wrap;
          color: #6b7280;
          font-size: #{[font_size - 1, 10].max}px;
          text-align: center;
        }
        .site-footer a { color: #2563eb; text-decoration: none; font-weight: 700; }
        .site-footer a:hover { text-decoration: underline; }
        @media (max-width: 900px) { .grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
        @media (max-width: 640px) {
          .site-header { padding: 0 16px; }
          .page { padding: 22px 12px 40px; }
          .site-footer { padding: 14px 12px 26px; gap: 8px; }
          .section h1 { font-size: 24px; }
          .grid { grid-template-columns: 1fr; }
        }
        @media (prefers-color-scheme: dark) {
          body { background: #111827; color: #e5e7eb; }
          .site-header, .card { background: #1f2937; border-color: #374151; }
          .section h1 { border-color: #374151; }
          .resource-title { color: #e5e7eb; }
          .site-footer { color: #9ca3af; }
          .site-footer a { color: #93c5fd; }
          .description, .empty { color: #9ca3af; }
        }
      CSS
    end
  end
end
