var React = require('react');
var ReactDOM = require('react-dom');
var io = require('socket.io-client');

var StatusItem = React.createClass({
  render: function() {
    var klass = this.props.item.ok ? 'bg-success' : 'bg-danger';
    return (
      <p className={klass}>{this.props.item.text}</p>
    );
  }
});

var TypewriterStatus = React.createClass({
  getInitialState: function () {
    return {
      comments: null
    };
  },
  componentDidMount: function () {
    var that = this;
    this.socket = io();
    this.socket.on('status', function (status) {
      that.setState({ status: status });
    });
    this.socket.emit('fetchStatus');
  },
  render: function() {
    return (
      <div className="commentBox">
        <h3>Status:</h3>
        <StatusList items={this.state.status}/>
      </div>
    );
  }
});

var StatusList = React.createClass({
  render: function () {
    var Items = (<div>Loading status...</div>);
    if (this.props.items) {
      Items = this.props.items.map(function (item) {
        return (<StatusItem item={item} />);
      });
    }
    return (
      <div className="statusList">
        {Items}
      </div>
    );
  }
});


var CommentBox = React.createClass({
  getInitialState: function () {
    return {
      comments: null
    };
  },
  componentDidMount: function () {
    var that = this;
    this.socket = io();
    this.socket.on('comments', function (comments) {
      that.setState({ comments: comments });
    });
    this.socket.emit('fetchComments');
  },
  submitComment: function (comment, callback) {
    this.socket.emit('newComment', comment, function (err) {
      if (err)
        return  console.error('New comment error:', err);
      callback();
    });
  },
  render: function() {
    return (
      <div className="commentBox">
        <h3>Comments:</h3>
        <CommentList comments={this.state.comments}/>
        <CommentForm submitComment={this.submitComment}/>
      </div>
    );
  }
});
var CommentList = React.createClass({
  render: function () {
    var Comments = (<div>Loading comments...</div>);
    if (this.props.comments) {
      Comments = this.props.comments.map(function (comment) {
        return (<Comment comment={comment} />);
      });
    }
    return (
      <div className="commentList">
        {Comments}
      </div>
    );
  }
});
var Comment = React.createClass({
  render: function () {
    return (
      <div className="comment">
        <span className="author">{this.props.comment.author}</span> said:<br/>
        <div className="body">{this.props.comment.text}</div>
      </div>
    );
  }
});
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

ReactDOM.render(
  <div>
    <TypewriterStatus/>
  </div>,
  document.getElementById('content')
);

