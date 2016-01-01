var React = require('react');
var ReactDOM = require('react-dom');
var io = require('socket.io-client');

var socket = io();

var CheckBox = React.createClass({
  getInitialState: function () {
    return {
      value: '',
      checked: false,
      text: '',
    };
  },
  handleChange: function(event) {
    this.setState({value: event.target.value});
  },
  render: function() {
    return (
      <div className="checkbox">
        <label>
          <input type="checkbox" value={this.props.value} checked={this.props.checked}
                 onChange={this.props.onChange} />
          {this.props.text}
        </label>
      </div>
    );
  }
});

var StatusItem = React.createClass({
  render: function() {
    var klass = this.props.value ? 'bg-success' : 'bg-danger';
    var text = this.props.value ? this.props.good : this.props.bad;
    return (
      <p className={klass}>{text}</p>
    );
  }
});

var Paper = React.createClass({
  render: function() {
    var style = {
      top: this.props.y * 18 || 0,
      left: this.props.x * 7.15 || 0, // for 13px <pre> font
    };
    var prestyle = {
      minHeight: style.top + 35,
    };
    return (
      <div className="paper">
        <pre style={prestyle}>{this.props.text}</pre>
        <div className="cursor" style={style}></div>
      </div>
    );
  }
});
var twitterTimelineCreated = false;
var TypewriterStatus = React.createClass({
  getInitialState: function () {
    return {config:{}, status: {}};
  },
  componentDidMount: function () {
    var that = this;
    socket.on('status', function (status) {
      console.log('got status');
      console.log(status);
      that.setState({ status: status });
      if (status.twitter && !twitterTimelineCreated) {
        twitterTimelineCreated = true;
        twttr.widgets.createTimeline(status.twitter.widget, document.getElementById("twitter"),
          { chrome: "nofooter noheader noborders noscrollbar", width: 'auto' });
      }
    });
    socket.on('config', function (config) {
      that.setState({ config: config });
    });
  },
  configChanged: function (event) {
    var config = {};
    config[event.target.value] = event.target.checked;
    socket.emit('updateConfig', config);
  },
  tweet: function (event) {
    if (this.state.status.text.length) {
      socket.emit('tweet', this.state.status.text);
    }
  },
  resetText: function (event) {
    socket.emit('resetText');
  },
  resetPosition: function (event) {
    socket.emit('resetPosition');
  },
  render: function() {
    var config = this.state.config;
    var connected = this.state.status.connected;
    var ips = '';
    if (this.state.status.ip) {
      ips = this.state.status.ip.map(function (ip) {
        return (<div>{ip.iface}: {ip.address}</div>);
      });
    }
    var style = {};
    if (!connected)
      style.display = 'none';
    return (
      <div className="commentBox">
        <h3>Status</h3>
        <StatusItem good="Device online" bad="Device offline" value={connected} />
        <StatusItem good="Keyboard connected" bad="Keyboard not connected" value={connected && this.state.status.keyboard} />
        <StatusItem good="Mouse connected" bad="Mouse not connected" value={connected && this.state.status.mouse} />
        <div style={style}>
          <Paper text={this.state.status.text} x={this.state.status.x} y={this.state.status.y} />
          <div className="paper">
            <pre>{this.state.status.tweetText}</pre>
          </div>
          <div>x={this.state.status.x}, y={this.state.status.y}</div>
          {ips}
          <CheckBox text="Ignore mouse" value="ignoreMouse" checked={config.ignoreMouse}
                    onChange={this.configChanged} />
          <input className="btn btn-default" type="button" onClick={this.tweet} value="Tweet" />
          <input className="btn btn-default" type="button" onClick={this.resetText} value="Reset text" />
          <input className="btn btn-default" type="button" onClick={this.resetPosition} value="Reset position" />
        </div>
      </div>
    );
  }
});

ReactDOM.render(
  <div>
    <TypewriterStatus/>
  </div>,
  document.getElementById('content')
);

