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
          :disabled="requestOngoing"
          :avoidAddingDuplicates="true"
          :autocomplete-items="autocompleteItems"
          :max-tags="5"
          :maxlength="50"
          :add-only-from-autocomplete="true"
          placeholder="Enter an ISIN or a ticker..."
        )
          template(v-slot:tag-right="{tag}")
            span(v-if="tag.isin") &nbsp; {{ "(" + tag.isin + ")" }}

          template(
            v-slot:autocomplete-item="{item, performAdd}"
          )
            div(@click="performAdd(item)")
              span &nbsp; {{ item.text }}
              span(v-if="item.isin") &nbsp; {{ '(' + item.isin + ')' }}
              span.em.small &nbsp; {{ item.name }}

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
      debounce: null
    }
  },
  mounted() {
    this.chart = new Chart(this.$refs.canvas, {
      type: 'line'
    })
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
        return
      }

      clearTimeout(this.debounce)

      this.debounce = setTimeout(async () => {
        try {
          let response = await this.restRequest('search', {
            params: {
              q: inputText
            }
          })
          this.autocompleteItems = response.map(({
            symbol,
            name,
            isin
          }) => ({
            symbol,
            name,
            isin,
            text: symbol
          }))
        } catch (error) {
          if (!error.response || error.response.status != 404) {
            throw error
          }
          this.autocompleteItems = []
        }
      }, 200)
    },
    tagsChanged(tags) {
      this.tags = tags
      this.updateChart()
    },
    async updateChart() {
      let datasets = await Promise.all(this.tags.filter(({symbol}) => symbol).map(async ({
        text,
        symbol
      }) => {

        try {
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
        } catch (error) {
          if (!error.response || error.response.status != 404) {
            throw error
          }
        }
        return null
      }))

      this.chart.data.datasets = datasets.filter(d => d)

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
