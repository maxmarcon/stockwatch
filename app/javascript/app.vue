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
            span(v-b-tooltip.hover :title="tag.name") {{ tag.text }}

          template(v-slot:tag-right="{tag}")
            span(v-if="tag.isin" v-b-tooltip.hover :title="tag.name") &nbsp; {{ "[" + tag.isin + "]" }}

          template(
            v-slot:autocomplete-item="{item, performAdd}"
          )
            div(@click="performAdd(item)")
              span &nbsp; {{ `${item.text} (${item.currency})` }}
              span(v-if="item.isin") &nbsp; {{ '[' + item.isin + ']' }}
              span.em.small &nbsp; {{ item.name }}

      b-col.mt-1(md="auto")
        b-form-select(:options="periods" v-model="period" @change="periodChanged")
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
      nextColor: 0
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
  methods: {
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
          tags: this.tags,
          period: this.period
        }))
      }
    },
    async tagsChanged(newTags) {
      this.tags = await this.updateDatasets(newTags)
      this.updateStorage()
    },
    periodChanged() {
      this.updateDatasets(this.tags)
      this.updateStorage()
    },
    async updateDatasets(newTags) {

      this.chart.data.datasets = this.chart.data.datasets
        .filter(({
          symbol
        }) => newTags.find(({
          text
        }) => text == symbol))

      for (let i = 0; i < newTags.length; ++i) {
        let tag = newTags[i]

        let currentDataset = this.chart.data.datasets.find(({
          symbol
        }) => symbol == tag.text)

        if (currentDataset && currentDataset.period != this.period) {
          let data = await this.fetchData(tag.text, this.period)
          if (data) {
            currentDataset.data = data.data
            currentDataset.period = this.period
          } else {
            tag.classes = 'ti-invalid'
          }

        } else if (!currentDataset) {
          let data = await this.fetchData(tag.text, this.period)

          if (data) {
            let color = COLORS[this.nextColor++ % COLORS.length]

            this.chart.data.datasets.push({
              symbol: tag.text,
              period: this.period,
              name: tag.name,
              label: `${tag.text} (${data.currency})`,
              yAxisID: data.currency,
              fill: false,
              backgroundColor: color,
              borderColor: color,
              data: data.data
            })
          } else {
            tag.classes = 'ti-invalid'
          }
        }
      }

      this.updateChart()

      return newTags
    },
    async fetchData(symbol, period) {
      try {
        let aggregate = 1
        switch (period) {
          case '5y':
          case '2y':
            aggregate = 30
            break
          case '1y':
          case '6m':
            aggregate = 7
            break
        }

        let response = await this.restRequest(`chart/${period}`, {
          params: {
            symbol,
            aggregate
          }
        })

        let data = response.data.map(({
          close,
          date
        }) => ({
          x: dateFns.parse(date),
          y: parseFloat(close).toFixed(2)
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

      this.chart.options = {
        scales: {
          yAxes,
          xAxes: [{
            type: 'time',
            time: {
              unit
            }
          }]
        },
        tooltips: {
          callbacks: {
            afterLabel: (tooltTipItem, data) => data.datasets[tooltTipItem.datasetIndex].name,
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

      this.chart.update()
    }
  }
}
</script>
