<template lang="pug">
b-card
  template(slot="header")
    message-bar#errorBar(ref="errorBar" variant="danger" :seconds=10)
    b-row
      b-col.mt-1(md="6")
        vue-tags-input(
          v-model="tag"
          :tags="tags"
          @tags-changed="tagsChanged"
          :avoidAddingDuplicates="true"
          :autocomplete-items="autocompleteItems"
          :max-tags="10"
          :maxlength="50"
          :add-only-from-autocomplete="true"
          placeholder="Search by name, ticker, or ISIN"
        )
          template(v-slot:tag-center="{tag}")
            span(v-b-tooltip.hover :title="tag.error || tag.name") {{ tag.text }}

          template(v-slot:tag-right="{tag}")
            span(v-if="tag.isin && !tag.error" v-b-tooltip.hover :title="tag.name") &nbsp; {{ "[" + tag.isin + "]" }}

          template(
            v-slot:autocomplete-item="{item, performAdd}"
          )
            div(@click="performAdd(item)")
              span &nbsp; {{ `${item.text} (${item.currency})` }}
              span(v-if="item.isin") &nbsp; {{ '[' + item.isin + ']' }}
              span.em.small &nbsp; {{ item.name }}

      b-col.mt-1(md="auto")
        b-form-select(:options="periods" v-model="period" @change="periodChanged" size="sm")
      b-col.mt-1(md="auto")
        .d-flex.justify-content-center
          b-spinner(v-if="updateOngoing")

  canvas(:style="{visibility: tags.length > 0 ? 'visible' : 'hidden'}" ref="canvas")
</template>
<script>
import VueTagsInput from '@johmun/vue-tags-input';
import {
  RestMixin
} from "./packs/globals"

import dateFns from 'date-fns'
import Chart from 'chart.js'

const COLORS = [
  '#5899DA',
  '#E8743B',
  '#19A979',
  '#ED4A7B',
  '#945ECF',
  '#13A4B4',
  '#525DF4',
  '#BF399E',
  '#6C8893',
  '#EE6868',
  '#2F6497'
]

const LOCAL_STORAGE_KEY = 'stockwatch_tags'

export default {
  mixins: [RestMixin],
  components: {
    VueTagsInput
  },
  data() {
    return {
      tags: [],
      tag: '',
      period: '1m',
      periods: [{
        value: '1m',
        text: '1 Month'
      }, {
        value: '3m',
        text: '3 Months'
      }, {
        value: '6m',
        text: '6 Months'
      }, {
        value: '1y',
        text: '1 Year'
      }, {
        value: '2y',
        text: '2 Years'
      }, {
        value: '5y',
        text: '5 Years'
      }],
      autocompleteItems: [],
      chart: null,
      searchQueryTimeout: null,
      nextColor: 0,
      ongoingUpdates: []
    }
  },
  mounted() {
    this.chart = new Chart(this.$refs.canvas, {
      type: 'line',
      data: {
        datasets: []
      },
      options: {
        tooltips: {
          callbacks: {
            afterLabel: (tooltTipItem, data) => data.datasets[tooltTipItem.datasetIndex].name,
            label: (tooltTipItem, data) =>
              data.datasets[tooltTipItem.datasetIndex].symbolAndCurrency +
              ': ' + tooltTipItem.value,
            title: (tooltTipItem, data) => {
              if (tooltTipItem instanceof Array) {
                tooltTipItem = tooltTipItem[0]
              }
              return dateFns.format(data.datasets[tooltTipItem.datasetIndex].data[tooltTipItem.index].x,
                'MMM D, YYYY')
            }
          }
        }
      }
    })

    setTimeout(() => {
      if (localStorage) {
        let savePoint = localStorage.getItem(LOCAL_STORAGE_KEY)
        if (savePoint) {
          const {
            period,
            tags
          } = JSON.parse(savePoint)
          if (period) {
            this.period = period
          }
          if (tags) {
            this.tagsChanged(tags)
          }
        }
      }
    }, 1500)
  },
  watch: {
    tag: function(newTag, _oldTag) {
      this.fillAutocomplete(newTag)
    }
  },
  computed: {
    updateOngoing() {
      return this.ongoingUpdates.length > 0
    }
  },
  methods: {
    growth(data) {
      let end_value = data[data.length - 1].y
      let start_value = data[0].y

      return (end_value > start_value ? '+' : '') + (((end_value - start_value) / start_value) * 100).toFixed(1) + '%'
    },
    fillAutocomplete(inputText) {
      inputText = inputText.trim()

      if (inputText.length < 3) {
        this.autocompleteItems = []
        return
      }

      clearTimeout(this.searchQueryTimeout)

      this.searchQueryTimeout = setTimeout(async () => {
        try {
          let response = await this.restRequest('search', {
            params: {
              q: inputText
            }
          })
          this.autocompleteItems = response.map(({
            symbol,
            name,
            isin,
            currency
          }) => ({
            text: symbol,
            name,
            isin,
            currency
          }))
        } catch (error) {
          this.autocompleteItems = []
          if (!error.response || error.response.status != 404) {
            throw error
          }
        }
      }, 200)
    },
    updateStorage() {
      if (localStorage) {
        localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify({
          tags: this.tags.map(({
            text,
            name,
            isin,
            currency
          }) => ({
            text,
            name,
            isin,
            currency
          })),
          period: this.period
        }))
      }
    },
    async tagsChanged(newTags) {
      console.log('tagsChanged: ' + newTags.map(({
        text
      }) => text).join(','))
      await this.updateDatasets(newTags)
      this.tags = newTags
      this.updateStorage()
    },
    periodChanged() {
      this.updateDatasets(this.tags)
      this.updateStorage()
    },
    async updateDatasets(newTags) {
      console.log('updateDatasets: ' + newTags.map(({
        text
      }) => `${text}`).join(','))

      // which tags need updates?
      let updates = newTags
        .filter(({
          text
        }) => {
          return !this.chart.data.datasets.find(({
              symbol,
              period
            }) => symbol == text && period == this.period) &&
            !this.ongoingUpdates.find(({
              symbol,
              period
            }) => symbol == text && period == this.period)
        })
        .map(({
          text
        }) => ({
          symbol: text,
          period: this.period
        }))

      this.ongoingUpdates = this.ongoingUpdates.concat(updates)

      console.log("new updates = " + updates.map(({
        symbol,
        period
      }) => `${symbol}:${period}`).join(','))

      let results = await Promise.all(updates.map(async ({
        symbol,
        period
      }) => {
        console.log("fetching: " + `${symbol}:${period}`)
        let data = await this.fetchData(symbol, period)
        return {
          data,
          symbol,
          period
        }
      }))

      this.ongoingUpdates = this.ongoingUpdates.filter((u) => !updates.includes(u))

      results.forEach(({
        data,
        period,
        symbol
      }) => {
        // is the result of this update still needed? Maybe the tag has been deleted
        // or the period has changed
        let tag = newTags.find(({
          text
        }) => text == symbol)

        console.log(`processing result of ${symbol}:${period}`)
        console.log("tags = " + newTags.map(({
          text
        }) => text).join(','))

        if (tag && period == this.period) {

          if (data) {
            tag.error = null
            tag.classes = null

            let dataset = this.chart.data.datasets.find(({
              symbol: _symbol
            }) => _symbol == symbol)

            let symbolAndCurrency = `${tag.text} (${data.currency})`
            let label = `${symbolAndCurrency} ${this.growth(data.data)}`

            if (dataset) {
              console.log('updating dataset')
              dataset.data = data.data
              dataset.period = period
              dataset.label = label
            } else {
              console.log('creating new dataset')
              let color = COLORS[this.nextColor++ % COLORS.length]

              this.chart.data.datasets.push({
                symbol: tag.text,
                period,
                name: tag.name,
                symbolAndCurrency,
                label,
                yAxisID: data.currency,
                fill: false,
                backgroundColor: color,
                borderColor: color,
                data: data.data
              })
            }
          } else {
            console.log('request failed')
            tag.classes = 'ti-invalid'
            tag.error = 'The data could not be retrieved'
          }
        } else {
          console.log('result discarded')
        }
      })

      // remove stale datasets
      this.chart.data.datasets = this.chart.data.datasets
        .filter(({
          period
        }) => period == this.period)
        .filter(({
          symbol
        }) => newTags.find(({
          text
        }) => text == symbol))

      this.updateChart()
    },
    async fetchData(symbol, period) {
      try {
        let response = await this.restRequest(`chart/${period}`, {
          params: {
            symbol,
            max_points: 150
          }
        })

        let data = response.data.map(({
          close,
          date
        }) => ({
          x: dateFns.parse(date),
          y: parseFloat(parseFloat(close).toFixed(2))
        }))

        return {
          data,
          currency: response.currency
        }
      } catch (error) {}
    },
    updateChart() {
      let currencies = this.chart.data.datasets.map(({
        yAxisID
      }) => yAxisID)

      let yAxes = currencies.map(currency => ({
        id: currency,
        type: 'linear',
        scaleLabel: {
          display: true,
          labelString: currency
        }
      }))

      let unit = 'day'
      switch (this.period) {
        case '1y':
        case '2y':
          unit = 'month'
          break
        case '5y':
          unit = 'quarter'
          break
        case '6m':
        case '3m':
          unit = 'week'
          break
        case '1m':
          unit = 'day'
          break
      }

      this.chart.options.scales = {
        yAxes,
        xAxes: [{
          type: 'time',
          time: {
            unit
          }
        }]
      }

      this.chart.update()
    }
  }
}
</script>
