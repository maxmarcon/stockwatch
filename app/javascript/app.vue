<template lang="pug">
b-card
  template(slot="header")
    message-bar#errorBar(ref="errorBar" variant="danger" :seconds=10)
    b-row
      b-col.mt-1(md="6")
        vue-tags-input(
          v-model="tag"
          :tags="tags"
          @tags-changed="newTags"
          @before-adding-tag="beforeAddingTag"
          :disabled="requestOngoing"
          :avoidAddingDuplicates="true"
          :max-tags="5"
          :maxlength="50"
          placeholder="Enter an ISIN or a ticker..."
        )
          template(slot="tag-right" slot-scope="props")
            span(v-if="props.tag.symbol != props.tag.text") &nbsp; {{ "(" + props.tag.symbol + ")" }}
      b-col.mt-1(md="auto")
        b-form-select(:options="periods" v-model="period" @change="updateChart")
      b-col.mt-1(md="auto")
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

export default {
  mixins: [RestMixin],
  components: {
    VueTagsInput
  },
  data() {
    return {
      tags: [],
      tag: '',
      symbol: null,
      symbols: ['AAAGX', 'SAP'],
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
      chart: null
    }
  },
  mounted() {
    this.chart = new Chart(this.$refs.canvas, {
      type: 'line'
    })
  },
  methods: {
    async beforeAddingTag({
      tag,
      addTag
    }) {
      tag.text = tag.text.toUpperCase()
      console.log("searching for... " + tag.text)
      try {
        let response = await this.restRequest('search', {
          params: {
            q: tag.text
          }
        })
        let iex_symbol = response[0]
        tag.symbol = iex_symbol.symbol
        addTag(tag)
      } catch (error) {
        if (error.response && error.response.status != 404) {
          throw error
        }
      }
    },
    newTags(tags) {
      this.tags = tags
      this.updateChart()
    },
    async updateChart() {
      let datasets = await Promise.all(this.tags.map(async ({
        text,
        symbol
      }) => {
        let response = await this.restRequest(`chart/${this.period}`, {
          params: {
            symbol: symbol
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
          label: symbol,
          fill: false,
          data
        }
      }))

      this.chart.data.datasets = datasets

      this.chart.options.scales = {
        yAxes: [{
          scaleLabel: {
            display: true,
            labelString: 'USD'
          },
          ticks: {
            min: 0
          }
        }],
        xAxes: [{
          type: 'time',
          time: {
            unit: 'month',
            displayFormats: {
              month: 'MMM YYYY'
            }
          }
        }]
      }
      this.chart.update()
    }
  }
}
</script>
