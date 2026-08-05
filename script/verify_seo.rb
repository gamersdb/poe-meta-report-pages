#!/usr/bin/env ruby

require "pathname"
require "rexml/document"
require "uri"

site_dir = Pathname(ARGV.fetch(0, "_site")).expand_path
site_url = "https://gamersdb.github.io"
baseurl = "/poe-meta-report-pages"
home_url = "#{site_url}#{baseurl}/"
verification_file = "google98c2b2400a556a1b.html"
errors = []

abort "Build directory not found: #{site_dir}" unless site_dir.directory?

html_files = site_dir.glob("**/*.html").reject do |path|
  path.relative_path_from(site_dir).to_s == verification_file
end

html_files.each do |path|
  relative = path.relative_path_from(site_dir).to_s
  html = path.read
  is_home = relative == "index.html"
  expected_robots = is_home ? "index,follow" : "noindex,follow"

  unless html.match?(%r{<meta name=["']robots["'] content=["']#{Regexp.escape(expected_robots)}["']>})
    errors << "#{relative}: expected robots=#{expected_robots}"
  end

  canonical = html[%r{<link rel=["']canonical["'] href=["']([^"']+)["']}, 1]
  errors << "#{relative}: missing canonical" unless canonical
  errors << "#{relative}: homepage canonical must be #{home_url}" if is_home && canonical != home_url

  next unless is_home

  h1_count = html.scan(/<h1(?:\s|>)/).size
  errors << "#{relative}: expected exactly one h1, found #{h1_count}" unless h1_count == 1
  errors << "#{relative}: missing machine-readable updated time" unless html.match?(%r{<time datetime=["'][^"']+["']>})
end

sitemap_path = site_dir.join("sitemap.xml")
if sitemap_path.file?
  sitemap = REXML::Document.new(sitemap_path.read)
  locations = []
  REXML::XPath.each(sitemap, "//*[local-name()='loc']") { |node| locations << node.text.to_s.strip }
  errors << "sitemap.xml: expected only #{home_url}, found #{locations.inspect}" unless locations == [home_url]
else
  errors << "sitemap.xml: missing"
end

robots_path = site_dir.join("robots.txt")
if robots_path.file?
  robots = robots_path.read
  errors << "robots.txt: missing Allow: /" unless robots.match?(/^Allow:\s*\/$/)
  errors << "robots.txt: must not contain Disallow" if robots.match?(/^Disallow:/)
  errors << "robots.txt: missing sitemap URL" unless robots.include?("Sitemap: #{site_url}#{baseurl}/sitemap.xml")
else
  errors << "robots.txt: missing"
end

html_files.each do |path|
  relative = path.relative_path_from(site_dir).to_s
  html = path.read
  html.scan(%r{href=["']([^"'#]+)}) do |match|
    href = match.first
    uri = URI.parse(href)
    next if uri.scheme && !["http", "https"].include?(uri.scheme)
    next if uri.host && uri.host != "gamersdb.github.io"

    link_path = uri.path
    next unless link_path.start_with?(baseurl)

    local_path = link_path.delete_prefix(baseurl).delete_prefix("/")
    target = site_dir.join(local_path)
    target = target.join("index.html") if link_path.end_with?("/")
    errors << "#{relative}: broken internal link #{href}" unless target.file?
  rescue URI::InvalidURIError
    errors << "#{relative}: invalid link #{href}"
  end
end


if errors.empty?
  puts "SEO verification passed for #{html_files.size} HTML pages."
else
  warn errors.join("\n")
  exit 1
end
