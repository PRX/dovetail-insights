# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development.

# Make sure RUBY_VERSION matches the Ruby version in .tool-versions
ARG RUBY_VERSION=3.4.5
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 libpq-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems and node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config libyaml-dev node-gyp python-is-python3 unzip && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install JavaScript dependencies
ARG NODE_VERSION=22.11.0
ARG YARN_VERSION=1.22.22
ARG BUN_VERSION=1.2.5
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master && \
    curl https://bun.sh/install | bash -s -- bun-v${BUN_VERSION}

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

ENV PATH="${PATH}:/root/.bun/bin"

# Install node modules
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY . .

RUN bun install

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


RUN rm -rf node_modules


# Final stage for app image
FROM base

LABEL maintainer="PRX <sysadmin@prx.org>"
LABEL org.prx.spire.publish.ecr="RAILS_APP"

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
