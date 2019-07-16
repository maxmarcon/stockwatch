const {
  environment
} = require('@rails/webpacker')
const {
  VueLoaderPlugin
} = require('vue-loader')

// This will make sure that webpack "sees" the relative URLs to the font files that appear
// in the fontawesome style sheets. Note: you need to import the stylesheets using JS import and not
// a SCSS @import statement.
// That is, use this:
// import '@fortawesome/fontawesome-free/scss/regular.scss';
// and not this:
// @import '~fortawesome/fontawesome-free/scss/regular.scss'
const CssUrlRelativePlugin = require('css-url-relative-plugin')
const vue = require('./loaders/vue')

environment.plugins.prepend('VueLoaderPlugin', new VueLoaderPlugin())
environment.plugins.prepend('CssUrlRelativePlugin', new CssUrlRelativePlugin())
environment.loaders.prepend('vue', vue)
environment.loaders.prepend('pug', {
  test: /\.pug$/,
  loader: 'pug-plain-loader'
})

module.exports = environment
