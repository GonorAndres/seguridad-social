FROM rocker/shiny:4.3.3

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('bslib', 'shinyjs', 'plotly', 'rmarkdown'), Ncpus=2)"

WORKDIR /app

COPY data/ data/
COPY R/ R/
COPY www/styles.css www/styles.css
COPY www/favicon.svg www/favicon.svg
COPY global.R .
COPY app.R .

EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('.', host='0.0.0.0', port=as.integer(Sys.getenv('PORT', '3838')), launch.browser=FALSE)"]
