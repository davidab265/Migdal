FROM node:21-alpine

WORKDIR /app

COPY . .

RUN npm install

EXPOSE 3000

# Run the Angular app
CMD ["npm", "start", "--", "--host", "0.0.0.0", "--disable-host-check", "--no-open"]