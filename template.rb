create_file '.tool-versions' do
  <<~TEXT
  ruby 3.2.2
  nodejs 20.11.1
  yarn 1.22.19
  TEXT
end

# General gems
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    gem "active_storage_validations"

    # This gem correctly configures Rails for Cloudflare
    # so that request.remote_ip / request.ip both work correctly.
    # Without this gem, the IP Addresses logged are Cloudflare IPs,
    # not the user's IP.
    # gem "cloudflare-rails"

    # Handles authentification [https://github.com/heartcombo/devise]
    gem "devise"

    # CSS Bundling for Rails [https://github.com/rails/cssbundling-rails]
    gem "cssbundling-rails"

    # JavaScript Bundling for Rails [https://github.com/rails/jsbundling-rails]
    gem "jsbundling-rails"

    # Hotwire"s modest JavaScript framework [https://stimulus.hotwired.dev]
    gem "stimulus-rails"

    # Hotwire"s SPA-like page accelerator [https://turbo.hotwired.dev]
    gem "turbo-rails"

    # Vite.js integration in Ruby web apps [https://vite-ruby.netlify.app/]
    gem "vite_rails", "~> 3.0"

    # Catch unsafe migrations in development [https://github.com/ankane/strong_migrations]
    gem "strong_migrations"

    # Helpful to have, but not always needed
    # gem "active_job-performs"
    # gem "active_record-associated_object"
    # gem "inline_svg", "~> 1.9"
    # gem "lookbook"
    # gem "maintenance_tasks", "~> 2.1"
    # gem "pghero"
    # gem "pg_query", ">= 2", "< 4"
    # gem "response_bank"
    # gem "view_component"

  RUBY
end

# Dev/Test gems
inject_into_file "Gemfile", after: 'gem "debug", platforms: %i[ mri windows ]' do
  <<-RUBY

  gem "brakeman"
  gem "benchmark-ips"

  gem "erb_lint", require: false
  gem "erblint-github"

  gem "guard", require: false
  gem "guard-rspec", require: false

  gem "rspec-rails"

  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  RUBY
end

# Dev gems
inject_into_file "Gemfile", after: 'group :development do' do
  <<-RUBY

  gem "annotate"
  gem "gindex"
  RUBY
end

# Test gems
inject_into_file "Gemfile", after: 'gem "selenium-webdriver"' do
  <<-RUBY

  gem "shoulda-matchers"
  gem "super_diff"
  RUBY
end


# Toggle some default gems
comment_lines 'Gemfile', /gem "jbuilder"/
comment_lines 'Gemfile', /gem "redis"/
uncomment_lines 'Gemfile', /gem "rack-mini-profiler"/

# Don't shrink to fit!
gsub_file(
  'app/views/layouts/application.html.erb',
  '<meta name="viewport" content="width=device-width,initial-scale=1">',
  '<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">'
)

# Needed for Devise
inject_into_file 'app/views/layouts/application.html.erb', after: '<body>' do
  <<-HTML

    <p class="notice"><%= notice %></p>
    <p class="alert"><%= alert %></p>
  HTML
end

# Configure ERB Lint
create_file '.erb-linters/erblint-github.rb', <<~RUBY
  require "erblint-github/linters"
RUBY

file '.erb-lint.yml', <<~YAML
  ---
  EnableDefaultLinters: true
  linters:
    ErbSafety:
      enabled: true
    Rubocop:
      enabled: true
      rubocop_config:
        inherit_from:
          - .rubocop.yml
  inherit_gem:
    erblint-github:
      - config/accessibility.yml
YAML

# Vite config
file 'vite.config.ts', <<~TYPESCRIPT, force: true
  import { defineConfig } from 'vite'
  import FullReload from 'vite-plugin-full-reload'
  import RubyPlugin from 'vite-plugin-ruby'
  import timulusHMR from 'vite-plugin-stimulus-hmr'

  export default defineConfig({
    clearScreen: false,
    plugins: [
      RubyPlugin(),
      StimulusHMR(),
      FullReload(['config/routes.rb', 'app/views/**/*'], { delay: 200 }),
    ],
  })
TYPESCRIPT

# Basic JS app bootstrap
create_file 'app/javascript/controllers/.keep', ''
create_file 'app/javascript/entrypoints/application.ts', <<~TYPESCRIPT, force: true
  import '@hotwired/turbo'

  import { Application } from '@hotwired/stimulus'
  import { registerControllers } from 'stimulus-vite-helpers'
  import 'trix'
  import '@rails/actiontext'

  declare global {
    interface Window {
      Stimulus: Application
    }
  }

  const application = Application.start()

  // Configure Stimulus development experience
  application.debug = false
  window.Stimulus = application

  const controllers = import.meta.glob('../**/*_controller.ts', { eager: true })
  registerControllers(application, controllers)

  export { application }
TYPESCRIPT

create_file 'package.json', <<~JSON
{
  "name": "#{app_name}",
  "private": true,
  "engines": {
    "node": "^20.11.1"
  }
}
JSON

create_file 'tsconfig.json', <<~JSON
{
  "compilerOptions": {
    "target": "es2016",
    "lib": [
      "dom",
      "dom.iterable",
      "es2016"
    ],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "esModuleInterop": true,
    "noEmit": true,
    "module": "esnext",
    "sourceMap": true,
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "downlevelIteration": true,
    "allowSyntheticDefaultImports": true,
    "noUnusedLocals": true,
    "types": [
      "vite/client"
    ]
  },
  "include": [
    "app/javascript/**/*.ts",
    "vite.config.ts"
  ],
  "exclude": [
    "node_modules"
  ]
}
JSON

# Install dependencies
after_bundle do
  # vite-rails needs a yarn.lock to know to `yarn add` dependencies
  run 'yarn install'

  run 'bundle exec vite install'
  run 'yarn add -D vite-plugin-full-reload vite-plugin-stimulus-hmr'

  run 'yarn add typescript @rails/actiontext @rails/activestorage @rails/request.js @types/rails__activestorage'

  run 'bin/rails turbo:install'
  run 'bin/rails stimulus:install'

  # Delete default Stimulus controllers
  run 'rm -f app/javascript/**/*.js'
end
