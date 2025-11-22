/** @type {import('next').NextConfig} */

const production = process.env.NODE_ENV === "production";

const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  output: 'export',
  images: {
    unoptimized: true,
  },
}

module.exports = nextConfig
