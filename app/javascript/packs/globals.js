export const RestMixin = {
  data() {
    return {
      requestOngoing: false,
      apiVersion: 'v1'
    }
  },
  methods: {
    async restRequest(path, config) {
      config = Object.assign({
        url: [null, this.apiVersion, path].join('/'),
        headers: {
          'Accept': 'application/json'
        },
        ignoreErrorStatus: [404],
      }, config);

      this.requestOngoing = true;

      try {
        let response = await this.$http.request(config)
        return response.data
      } catch (error) {
        let message = (error.response ? error.response.data.message : "An error occurred")
        if (this.$refs.errorBar && (!error.response || !config.ignoreErrorStatus.includes(error.response.status))) {
          this.$refs.errorBar.show(message)
        }
        throw error
      } finally {
        this.requestOngoing = false;
      }
    }
  }
}
