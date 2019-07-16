<template lang="pug">
b-container
  message-bar#errorBar(ref="errorBar" variant="danger" :seconds=10)
  b-row.mt-3
    b-col(md="2")
      b-form-select(:options="symbols" v-model="symbol" @change="loadSymbol")
        template(slot="first")
          option(:value="null" disabled) Select a symbol
    b-col(md="2")
      b-form-select(:options="periods" v-model="period" @change="loadSymbol")

  b-row
    b-col
      canvas(ref="canvas")
</template>

<script>
import {
  RestMixin
} from "./packs/globals"

import dateFns from 'date-fns'
import Chart from 'chart.js'

export default {
  mixins: [RestMixin],
  data() {
    return {
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
      }]
    }
  },
  methods: {
    async loadSymbol() {
      if (!this.symbol || !this.period) {
        return
      }

      console.log(`loading ${this.symbol}`)

      let response = await this.restRequest(`chart/${this.period}`, {
        params: {
          symbol: this.symbol
        }
      })

console.dir(response)
      let data = response.data.map(({
        close,
        date
      }) => ({
        x: dateFns.parse(date),
        y: close
      }))

      let chart = new Chart(this.$refs.canvas, {
        type: 'line',
        data: {
          datasets: [{
            label: this.symbol,
            fill: false,
            data
          }]
        },
        options: {
          scales: {
            yAxes: [{
              scaleLabel: {
                display: true,
                labelString: response.currency
              },
              ticks: {
                beginAtZero: true
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
        }
      })
    }
  }
}
</script>
