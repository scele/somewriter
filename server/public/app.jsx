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
      top: this.props.y * 16,
      left: this.props.x * 7.15, // for 13px <pre> font
    };
    return (
      <div className="paper">
        <pre>{this.props.text}</pre>
        <div className="cursor" style={style}></div>
      </div>
    );
  }
});

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
    });
    socket.on('text', function (text) {
      that.setState({ text: text });
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
  render: function() {
    var config = this.state.config;
    return (
      <div className="commentBox">
        <h3>Status</h3>
        <StatusItem good="Device online" bad="Device offline" value={this.state.status.connected} />
        <StatusItem good="Keyboard connected" bad="Keyboard not connected" value={this.state.status.keyboard} />
        <StatusItem good="Mouse connected" bad="Mouse not connected" value={this.state.status.mouse} />
        <Paper text={this.state.text} x={this.state.status.x} y={this.state.status.y} />
        <div>x={this.state.status.x}, y={this.state.status.y}</div>
        <CheckBox text="Ignore mouse" value="ignoreMouse" checked={config.ignoreMouse}
                  onChange={this.configChanged} />
      </div>
    );
  }
});

/*
var CommentForm = React.createClass({
  handleSubmit: function (e) {
    e.preventDefault();
    var that = this;
    var author = this.refs.author.getDOMNode().value;
    var text = this.refs.text.getDOMNode().value;
    var comment = { author: author, text: text };
    var submitButton = this.refs.submitButton.getDOMNode();
    submitButton.innerHTML = 'Posting comment...';
    submitButton.setAttribute('disabled', 'disabled');
    this.props.submitComment(comment, function (err) {
      that.refs.author.getDOMNode().value = '';
      that.refs.text.getDOMNode().value = '';
      submitButton.innerHTML = 'Post comment';
      submitButton.removeAttribute('disabled');
    });
  },
  render: function () {
    return (
      <form className="commentForm" onSubmit={this.handleSubmit}>
        <input type="text" name="author" ref="author" placeholder="Name" required /><br/>
        <textarea name="text" ref="text" placeholder="Comment" required></textarea><br/>
        <button type="submit" ref="submitButton">Post comment</button>
      </form>
    );
  }
});
*/

ReactDOM.render(
  <div>
    <TypewriterStatus/>
  </div>,
  document.getElementById('content')
);

