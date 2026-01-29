#!/usr/bin/env python3
"""A simple TUI for browsing lemmy.ml using Textual."""

import httpx
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, VerticalScroll
from textual.message import Message
from textual.widgets import (
    Footer,
    Header,
    Label,
    ListItem,
    ListView,
    Static,
    Tree,
)
from textual.widgets.tree import TreeNode

BASE_URL = "https://lemmy.ml/api/v3"


class LemmyAPI:
    """Simple Lemmy API client."""

    def __init__(self, base_url: str = BASE_URL):
        self.base_url = base_url
        self.client = httpx.Client(timeout=30.0)

    def get_posts(self, community_id: int | None = None, sort: str = "Hot", limit: int = 25) -> list[dict]:
        """Get posts from the front page or a specific community."""
        params = {"sort": sort, "limit": limit, "type_": "All"}
        if community_id:
            params["community_id"] = community_id
        resp = self.client.get(f"{self.base_url}/post/list", params=params)
        resp.raise_for_status()
        return resp.json().get("posts", [])

    def get_comments(self, post_id: int, sort: str = "Hot", max_depth: int = 8) -> list[dict]:
        """Get comments for a post."""
        params = {"post_id": post_id, "sort": sort, "max_depth": max_depth, "type_": "All"}
        resp = self.client.get(f"{self.base_url}/comment/list", params=params)
        resp.raise_for_status()
        return resp.json().get("comments", [])

    def get_communities(self, sort: str = "Hot", limit: int = 50) -> list[dict]:
        """Get list of communities."""
        params = {"sort": sort, "limit": limit, "type_": "All"}
        resp = self.client.get(f"{self.base_url}/community/list", params=params)
        resp.raise_for_status()
        return resp.json().get("communities", [])


class PostsList(ListView):
    """Widget showing a list of posts."""

    def __init__(self, posts: list[dict], **kwargs):
        super().__init__(**kwargs)
        self.posts = posts

    def compose(self) -> ComposeResult:
        for post in self.posts:
            post_view = post["post"]
            counts = post["counts"]
            community = post["community"]
            creator = post["creator"]

            title = post_view.get("name", "Untitled")
            score = counts.get("score", 0)
            comments = counts.get("comments", 0)
            community_name = community.get("name", "unknown")
            author = creator.get("name", "unknown")

            label = (
                f"[bold]{title}[/bold]\n[dim]{score} pts | {comments} comments | c/{community_name} | u/{author}[/dim]"
            )
            item = ListItem(Label(label, markup=True), id=f"post-{post_view['id']}")
            item.post_data = post
            yield item


class CommentsTree(Tree):
    """Widget showing comments as a collapsible tree."""

    class CommentSelected(Message):
        """Message sent when a comment is selected."""

        def __init__(self, comment_data: dict) -> None:
            self.comment_data = comment_data
            super().__init__()

    def __init__(self, comments: list[dict], **kwargs):
        super().__init__("Comments", **kwargs)
        self.comments_data = comments

    def on_mount(self) -> None:
        self.root.expand()
        self._build_tree()

    def _build_tree(self) -> None:
        """Build the comment tree from flat list."""
        # Index comments by ID
        by_id: dict[int, dict] = {}
        for c in self.comments_data:
            comment = c["comment"]
            by_id[comment["id"]] = c

        # Find parent->children relationships using the path
        children: dict[int | None, list[dict]] = {None: []}
        for c in self.comments_data:
            comment = c["comment"]
            path = comment.get("path", "0")
            parts = [int(p) for p in path.split(".") if p != "0"]

            if len(parts) <= 1:
                # Top-level comment
                children.setdefault(None, []).append(c)
            else:
                # Has parent - parent is second-to-last in path
                parent_id = parts[-2]
                children.setdefault(parent_id, []).append(c)

        # Build tree recursively
        def add_children(node: TreeNode, parent_id: int | None) -> None:
            for c in children.get(parent_id, []):
                comment = c["comment"]
                counts = c["counts"]
                creator = c["creator"]

                author = creator.get("name", "unknown")
                score = counts.get("score", 0)
                content = comment.get("content", "")
                # Truncate long comments for the tree label
                preview = content[:100] + "..." if len(content) > 100 else content
                preview = preview.replace("\n", " ")

                label = f"[bold cyan]u/{author}[/bold cyan] [dim]({score} pts)[/dim] {preview}"
                child_node = node.add(label, data=c, expand=True)
                child_node.allow_expand = True
                add_children(child_node, comment["id"])

        add_children(self.root, None)

    def on_tree_node_highlighted(self, event: Tree.NodeHighlighted) -> None:
        """Handle node highlight (cursor movement) - post message with comment data."""
        if event.node.data:
            self.post_message(self.CommentSelected(event.node.data))


class PostView(Container):
    """View for a single post with its comments."""

    def __init__(self, post: dict, comments: list[dict], **kwargs):
        super().__init__(**kwargs)
        self.post = post
        self.comments = comments

    def compose(self) -> ComposeResult:
        post_view = self.post["post"]
        counts = self.post["counts"]
        creator = self.post["creator"]
        community = self.post["community"]

        title = post_view.get("name", "Untitled")
        body = post_view.get("body", "")
        url = post_view.get("url", "")
        score = counts.get("score", 0)
        comment_count = counts.get("comments", 0)
        author = creator.get("name", "unknown")
        community_name = community.get("name", "unknown")

        # Post header
        header_text = f"[bold]{title}[/bold]\n"
        header_text += f"[dim]c/{community_name} | u/{author} | {score} pts | {comment_count} comments[/dim]"
        if url:
            header_text += f"\n[link]{url}[/link]"

        yield Static(header_text, markup=True, id="post-header")

        if body:
            yield Static(f"\n{body}\n", id="post-body")

        with Horizontal(id="comments-container"):
            with VerticalScroll(id="tree-panel"):
                yield CommentsTree(self.comments, id="comments-tree")
            with VerticalScroll(id="detail-panel"):
                yield Static("[dim]Select a comment to view full text[/dim]", id="comment-detail", markup=True)

    def on_comments_tree_comment_selected(self, event: CommentsTree.CommentSelected) -> None:
        """Update detail panel when a comment is selected."""
        c = event.comment_data
        comment = c["comment"]
        counts = c["counts"]
        creator = c["creator"]

        author = creator.get("name", "unknown")
        score = counts.get("score", 0)
        content = comment.get("content", "")

        detail_text = f"[bold cyan]u/{author}[/bold cyan] [dim]({score} pts)[/dim]\n\n{content}"

        detail = self.query_one("#comment-detail", Static)
        detail.update(detail_text)


class CommunityList(ListView):
    """Widget showing a list of communities."""

    def __init__(self, communities: list[dict], **kwargs):
        super().__init__(**kwargs)
        self.communities = communities

    def compose(self) -> ComposeResult:
        # Add "Front Page" option
        item = ListItem(Label("[bold]Front Page[/bold] (All)", markup=True), id="community-front")
        item.community_id = None
        item.community_display = "Front Page"
        yield item

        for comm in self.communities:
            community = comm["community"]
            counts = comm["counts"]

            cid = community.get("id")
            name = community.get("name", "unknown")
            title = community.get("title", name)
            subscribers = counts.get("subscribers", 0)

            label = f"[bold]c/{name}[/bold] - {title}\n[dim]{subscribers} subscribers[/dim]"
            item = ListItem(Label(label, markup=True), id=f"community-{cid}")
            item.community_id = cid
            item.community_display = f"c/{name}"
            yield item


class LemmyBrowser(App):
    """Main Lemmy browser application."""

    CSS = """
    #post-header {
        background: $surface;
        padding: 1;
        margin-bottom: 1;
    }

    #post-body {
        padding: 0 1;
        margin-bottom: 1;
    }

    PostsList, CommunityList {
        height: 100%;
    }

    PostsList ListItem, CommunityList ListItem {
        padding: 1;
    }

    #comments-container {
        height: 1fr;
    }

    #tree-panel {
        width: 1fr;
        border-right: solid $primary;
    }

    #detail-panel {
        width: 1fr;
        padding: 1;
    }

    #comment-detail {
        padding: 1;
    }

    CommentsTree {
        padding: 1;
    }

    #status-bar {
        dock: bottom;
        height: 1;
        background: $primary;
        color: $text;
        padding: 0 1;
    }
    """

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("escape", "go_back", "Back"),
        Binding("c", "show_communities", "Communities"),
        Binding("h", "go_home", "Home"),
        Binding("r", "refresh", "Refresh"),
    ]

    def __init__(self):
        super().__init__()
        self.api = LemmyAPI()
        self.current_view = "posts"
        self.current_community_id: int | None = None
        self.current_community_display: str = "Front Page"
        self.current_post: dict | None = None

    def compose(self) -> ComposeResult:
        yield Header()
        yield Container(id="main-content")
        yield Static("Loading...", id="status-bar")
        yield Footer()

    def on_mount(self) -> None:
        self.title = "Lemmy Browser"
        self.load_posts()

    def load_posts(self) -> None:
        """Load and display posts."""
        self.current_view = "posts"
        container = self.query_one("#main-content")
        container.remove_children()

        status = self.query_one("#status-bar", Static)
        status.update(f"Loading posts from {self.current_community_display}...")

        try:
            posts = self.api.get_posts(community_id=self.current_community_id)
            container.mount(PostsList(posts, id="posts-list"))
            status.update(
                f"{self.current_community_display} | {len(posts)} posts | Enter: open | c: communities | h: home | q: quit"
            )
        except Exception as e:
            container.mount(Static(f"Error loading posts: {e}"))
            status.update("Error")

    def load_post_detail(self, post: dict) -> None:
        """Load and display a single post with comments."""
        self.current_view = "post_detail"
        self.current_post = post
        container = self.query_one("#main-content")
        container.remove_children()

        status = self.query_one("#status-bar", Static)
        status.update("Loading comments...")

        try:
            post_id = post["post"]["id"]
            comments = self.api.get_comments(post_id)
            container.mount(PostView(post, comments))
            status.update(
                f"{len(comments)} comments | Arrows: navigate/view | Enter/Space: collapse/expand | Esc: back"
            )
        except Exception as e:
            container.mount(Static(f"Error loading comments: {e}"))
            status.update("Error")

    def load_communities(self) -> None:
        """Load and display communities list."""
        self.current_view = "communities"
        container = self.query_one("#main-content")
        container.remove_children()

        status = self.query_one("#status-bar", Static)
        status.update("Loading communities...")

        try:
            communities = self.api.get_communities()
            container.mount(CommunityList(communities, id="community-list"))
            status.update(f"{len(communities)} communities | Enter: select | Esc: back | h: home")
        except Exception as e:
            container.mount(Static(f"Error loading communities: {e}"))
            status.update("Error")

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle selection in list views."""
        item = event.item

        if hasattr(item, "post_data"):
            # Selected a post
            self.load_post_detail(item.post_data)
        elif hasattr(item, "community_id"):
            # Selected a community
            self.current_community_id = item.community_id
            self.current_community_display = item.community_display
            self.load_posts()

    def action_go_back(self) -> None:
        """Go back to previous view."""
        if self.current_view == "post_detail" or self.current_view == "communities":
            self.load_posts()

    def action_show_communities(self) -> None:
        """Show communities list."""
        self.load_communities()

    def action_go_home(self) -> None:
        """Go to front page."""
        self.current_community_id = None
        self.current_community_display = "Front Page"
        self.load_posts()

    def action_refresh(self) -> None:
        """Refresh current view."""
        if self.current_view == "posts":
            self.load_posts()
        elif self.current_view == "post_detail" and self.current_post:
            self.load_post_detail(self.current_post)
        elif self.current_view == "communities":
            self.load_communities()


if __name__ == "__main__":
    app = LemmyBrowser()
    app.run()
