<template lang="pug">
b-container
  message-bar#errorBar(ref="errorBar" variant="danger" :seconds=10)
  stock-chart(v-if="loaded" :chart-data="chartData" :chart-options="chartOptions")
</template>

<script>
import {
  RestMixin
} from "./packs/globals"

import dateFns from 'date-fns'
import StockChart from './packs/stockChart'
export default {
  mixins: [RestMixin],
  components: {
    'stock-chart': StockChart
  },
  data() {
    return {
      loaded: false,
      chartData: null,
      chartOptions: null,
    }
  },
  async mounted() {
    let jsonData = await this.restRequest('chart/1y', {
      params: {
        symbol: 'SAP'
      }
    })

    this.chartData = {
      datasets: [{
        label: 'SAP',
        fill: false,
        data: jsonData.data.map(({
          close,
          date
        }) => ({
          x: dateFns.parse(date),
          y: close
        }))
      }]
    }

    this.chartOptions = {
      scales: {
        yAxes: [{
          scaleLabel: {
            display: true,
            labelString: 'USD'
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

    this.loaded = true


  }
}
</script>
