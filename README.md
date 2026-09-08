# Discourse Resources HTML

独立 Ruby 插件，提供完整 HTML 页面：

```text
/summary/resources
```

```yaml
          - git clone https://github.com/zaixiangjian/discourse-resources-html.git
```

它不是主题组件，也不是 Discourse 内部 404 页面替换。访问该地址时，后端直接返回完整 HTML：

```html
<!DOCTYPE html>
<html>...</html>
```

## 后台设置

- `resources_html_enabled`：启用/关闭
- `resources_html_columns`：每行 1-3 个卡片
- `resources_html_font_size`：文字大小，范围 10-24
- `resources_html_content`：Markdown 风格内容

## 内容格式

### 论坛用户

标题以 `@` 开头时，会跳转论坛用户页 `/u/用户名`：

```markdown
# 赞助商

## @123
官网：https://example.com
说明：简单说明

## @456
说明：简单说明
```

### 普通链接 / 友情链接

标题不以 `@` 开头时，只显示普通名称，不会跳转 `/u/`：

```markdown
# 友情链接

## 某某博客
官网：https://example.com
说明：简单说明

## 某某博客2
官网：https://example.com
说明：简单说明
```

- `# 赞助商`：板块名
- `## @123`：论坛用户名，点击跳转 `/u/123`
- `## 某某博客`：普通名称，不跳转论坛用户页
- `官网：`：可选，填写才显示官网按钮
- `说明：`：简单说明

外链自动加：

```html
rel="noopener nofollow noreferrer"
referrerpolicy="no-referrer"
target="_blank"
```

页面响应头加：

```http
X-Robots-Tag: noindex, nofollow, noarchive, nosnippet
```
