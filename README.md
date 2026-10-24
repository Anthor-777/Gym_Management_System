# Sinewforge Fitness

A desktop-first gym membership website prototype. Vue 3 owns the page mount and updates rendered views, while the existing route templates and delegated interactions remain in `js/app.js`. Tailwind CSS v4 utilities are available through its browser CDN, alongside the site’s custom dark gym theme. There is no build step or backend. Open `index.html` directly in a browser, or serve this folder with any static web server. Internet access is needed for Vue, Tailwind, Google Fonts, Chart.js, Swiper, Lucide and the remote photo assets.

Tailwind’s browser CDN is intended for development and prototyping. For a production deployment, compile Tailwind to a local stylesheet with the Tailwind CLI. Vue is loaded from its production CDN build.

## Demo sign in

- Member: `member1@example.com` (seeded members `member1@example.com` through `member24@example.com`)
- Staff or owner: `owner@sinewforge.fit`
- The one-time code is simulated in an on-screen toast. It expires in five minutes, resend is limited to once every 30 seconds, and three wrong attempts lock sign-in for 60 seconds.
- Checkout is a local simulation. It does not collect or transmit real payment details.

## Where to edit things

- Brand name, slogans, contact details, hours, and plan fees/perks: `js/config.js`
- Seed records and realistic relative dates: `js/data.js`
- localStorage repository, validation rules, and business constraints: `js/store.js`
- Page views and interactions: `js/app.js`
- Design tokens: `css/tokens.css`
- Shared layout and components: `css/styles.css`

Data is stored in the browser under `sinewforge.v1`. Clear that localStorage key to restore the original seed data. The repository API in `js/store.js` is isolated from page rendering so it can be replaced with HTTP calls later.

## Data and prototype notes

Seed records follow the nine entities in the case study. The join table for the many-to-many member/session relationship is represented as `bookings`, and plan presentation perks live in the frontend brand configuration. OTP delivery and payment processing are simulated for portfolio demonstration; production use needs a server, a real identity provider, and a payment gateway.

## CDN assets

Chart.js 4.4.7, Swiper 11.1.15, Lucide Static 0.468.0, and the Google Fonts stylesheet are pinned in `index.html`. Their resource URLs were checked with HTTP HEAD requests and returned status 200.
