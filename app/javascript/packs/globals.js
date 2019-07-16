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
        }
      }, config);

      let self = this;

      this.requestOngoing = true;

      try {
        let response = await this.$http.request(config)
        return response.data
      } catch (error) {
        let message = (error.response ? error.response.data.message : "An error occurred")
        console.log(error)
        if (this.$refs.errorBar) {
          this.$refs.errorBar.show(message)
        }
        throw error
      } finally {
        self.requestOngoing = false;
      }
    }
  }
}
