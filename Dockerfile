FROM library/ruby:2.6.5

RUN apt-get update && \
    apt-get install -y && \

    wget https://chromedriver.storage.googleapis.com/96.0.4664.45/chromedriver_linux64.zip && \
    unzip chromedriver_linux64.zip && \
    mv chromedriver /usr/bin/chromedriver && \
    chmod +x /usr/bin/chromedriver && \

    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' >> /etc/apt/sources.list.d/google.list && \
    apt-get update && \
    apt-get install -y google-chrome-stable

WORKDIR /usr/src/app
COPY Gemfile .
RUN bundle install
COPY . .

CMD ["bin/run", "locations", "--profile_dir=chrome_1", "--log_level=DEBUG"]
