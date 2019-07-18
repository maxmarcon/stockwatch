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
          :max-tags="5"
          :maxlength="50"
          :add-only-from-autocomplete="true"
          placeholder="Enter an ISIN or a ticker..."
        )
          template(v-slot:tag-right="{tag}")
            span(v-if="tag.isin") &nbsp; {{ "[" + tag.isin + "]" }}

          template(
            v-slot:autocomplete-item="{item, performAdd}"
          )
            div(@click="performAdd(item)")
              span &nbsp; {{ `${item.text} (${item.currency})` }}
              span(v-if="item.isin") &nbsp; {{ '[' + item.isin + ']' }}
              span.em.small &nbsp; {{ item.name }}

      b-col.mt-1(md="auto")
        b-form-select(:options="periods" v-model="period" @change="updateDatasets")
      b-col.mt-2(md="auto")
        .d-flex.justify-content-center
          b-spinner(v-if="requestOngoing")

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
  'rgba(51,204,0,0.2)',
  'rgba(0,153,255,0.2)',
  'rgba(255,51,51,0.2)',
  'rgba(255,255,0,0.2)',
  'rgba(0,0,0,0.2)'
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
      searchQueryTimeout: null
    }
  },
  mounted() {
    this.chart = new Chart(this.$refs.canvas, {
      type: 'line'
    })

    setTimeout(() => {
      if (localStorage) {
        let savePoint = localStorage.getItem(LOCAL_STORAGE_KEY)
        if (savePoint) {
          const {period, tags} = JSON.parse(savePoint)
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
  methods: {
    fillAutocomplete(inputText) {
      inputText = inputText.trim()

      if (inputText.length < 2) {
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
    tagsChanged(newTags) {
      this.tags = newTags
      this.updateDatasets()
    },
    async updateDatasets() {

      let tagsToInvalidate = []

      for (let i = 0; i < this.tags.length; ++i) {
        let tag = this.tags[i]

        let currentDataset = this.chart.data.datasets.find(({
          symbol
        }) => symbol == tag.text)

        if (currentDataset && currentDataset.period != this.period) {
          let data = await this.fetchData(tag.text, this.period)
          if (data) {
            currentDataset.data = data.data
            currentDataset.period = this.period
          } else {
            tagsToInvalidate.push(i)
          }

        } else if (!currentDataset) {
          let data = await this.fetchData(tag.text, this.period)

          if (data) {
            let color = COLORS[this.chart.data.datasets.length % COLORS.length]

            this.chart.data.datasets.push({
              symbol: tag.text,
              period: this.period,
              label: `${tag.text} (${data.currency})`,
              yAxisID: data.currency,
              fill: false,
              backgroundColor: color,
              borderColor: color,
              data: data.data
            })
          } else {
            tagsToInvalidate.push(i)
          }
        }
      }

      this.chart.data.datasets = this.chart.data.datasets
        .filter(({
          symbol
        }) => this.tags.find(({
          text
        }) => text == symbol))

      tagsToInvalidate.forEach(i => {
        this.tags.splice(i, 1, Object.assign({}, this.tags[i], {
          classes: 'ti-invalid'
        }))
      })

      this.updateChart()

      if (localStorage) {
        localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify({
          tags: this.tags,
          period: this.period
        }))
      }
    },
    async fetchData(symbol, period) {
      try {
        let response = await this.restRequest(`chart/${period}`, {
          params: {
            symbol
          }
        })

        let data = response.data.map(({
          close,
          date
        }) => ({
          x: dateFns.parse(date),
          y: close
        }))

        return {
          data,
          currency: response.currency
        }

      } catch (error) {
        if (!error.response || error.response.status != 404) {
          throw error
        }
      }
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

      let unit = null
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
        default:
          unit = 'day'
      }

      this.chart.options = {
        scales: {
          yAxes,
          xAxes: [{
            type: 'time',
            time: {
              unit
            }
          }]
        }
      }

      this.chart.update()
    }
  }
}
</script>
