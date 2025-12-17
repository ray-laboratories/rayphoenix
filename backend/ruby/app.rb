require 'sinatra'
require 'sinatra/json'
require 'net/http'
require 'json'
require 'uri'

# Configuration
GO_SERVICE_URL = ENV['GO_SERVICE_URL'] || 'http://localhost:8080'

# Enable CORS
before do
  headers 'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => ['GET', 'POST', 'DELETE', 'OPTIONS'],
          'Access-Control-Allow-Headers' => 'Content-Type'
end

options '*' do
  200
end

# Homepage - Management Interface
get '/' do
  erb :index
end

# API: Get all links
get '/api/links' do
  uri = URI("#{GO_SERVICE_URL}/api/links")
  response = Net::HTTP.get_response(uri)
  
  content_type :json
  response.body
end

# API: Create a new short link
post '/api/links' do
  data = JSON.parse(request.body.read)
  
  # Validate input
  if data['short_code'].nil? || data['short_code'].empty?
    halt 400, json({ error: 'Short code is required' })
  end
  
  if data['long_url'].nil? || data['long_url'].empty?
    halt 400, json({ error: 'Long URL is required' })
  end
  
  # Validate URL format
  unless data['long_url'] =~ URI::DEFAULT_PARSER.make_regexp(['http', 'https'])
    halt 400, json({ error: 'Invalid URL format' })
  end
  
  # Validate short code format (alphanumeric only)
  unless data['short_code'] =~ /^[a-zA-Z0-9_-]+$/
    halt 400, json({ error: 'Short code must be alphanumeric (with _ or -)' })
  end
  
  # Forward to Go service
  uri = URI("#{GO_SERVICE_URL}/api/links")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
  request.body = data.to_json
  
  response = http.request(request)
  
  status response.code.to_i
  content_type :json
  response.body
end

# API: Delete a link
delete '/api/links/:short_code' do
  short_code = params[:short_code]
  
  uri = URI("#{GO_SERVICE_URL}/api/links/#{short_code}")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Delete.new(uri.path)
  
  response = http.request(request)
  
  status response.code.to_i
  content_type :json
  json({ message: 'Link deleted successfully' })
end

# Generate random short code
get '/api/generate-code' do
  code = (0...6).map { ('a'..'z').to_a[rand(26)] }.join
  json({ code: code })
end

__END__

@@index
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rayphoenix - URL Shortener</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        header {
            text-align: center;
            color: white;
            margin-bottom: 40px;
        }
        
        h1 {
            font-size: 3em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        
        .subtitle {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .card {
            background: white;
            border-radius: 12px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            margin-bottom: 30px;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #333;
        }
        
        input {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .button-group {
            display: flex;
            gap: 10px;
        }
        
        button {
            flex: 1;
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }
        
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(102, 126, 234, 0.4);
        }
        
        .btn-secondary {
            background: #f0f0f0;
            color: #333;
        }
        
        .btn-secondary:hover {
            background: #e0e0e0;
        }
        
        .links-table {
            width: 100%;
            border-collapse: collapse;
        }
        
        .links-table th {
            background: #f8f9fa;
            padding: 12px;
            text-align: left;
            font-weight: 600;
            color: #555;
            border-bottom: 2px solid #dee2e6;
        }
        
        .links-table td {
            padding: 12px;
            border-bottom: 1px solid #dee2e6;
        }
        
        .links-table tr:hover {
            background: #f8f9fa;
        }
        
        .short-link {
            color: #667eea;
            font-weight: 600;
            text-decoration: none;
        }
        
        .short-link:hover {
            text-decoration: underline;
        }
        
        .btn-delete {
            background: #dc3545;
            color: white;
            padding: 6px 12px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
        }
        
        .btn-delete:hover {
            background: #c82333;
        }
        
        .stats {
            display: flex;
            justify-content: space-around;
            margin-bottom: 30px;
        }
        
        .stat-box {
            text-align: center;
            padding: 20px;
            background: white;
            border-radius: 12px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
            flex: 1;
            margin: 0 10px;
        }
        
        .stat-number {
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
        }
        
        .stat-label {
            color: #666;
            margin-top: 5px;
        }
        
        .message {
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: none;
        }
        
        .message.success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .message.error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .empty-state {
            text-align: center;
            padding: 40px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🔥 Rayphoenix</h1>
            <p class="subtitle">Lightning-fast URL shortening powered by Go & Ruby</p>
        </header>
        
        <div class="stats">
            <div class="stat-box">
                <div class="stat-number" id="totalLinks">0</div>
                <div class="stat-label">Total Links</div>
            </div>
            <div class="stat-box">
                <div class="stat-number" id="totalClicks">0</div>
                <div class="stat-label">Total Clicks</div>
            </div>
        </div>
        
        <div class="card">
            <h2>Create Short Link</h2>
            <div id="message" class="message"></div>
            <form id="createForm">
                <div class="form-group">
                    <label for="shortCode">Short Code</label>
                    <input type="text" id="shortCode" placeholder="e.g., github" required>
                </div>
                <div class="form-group">
                    <label for="longUrl">Long URL</label>
                    <input type="url" id="longUrl" placeholder="https://example.com/very/long/url" required>
                </div>
                <div class="button-group">
                    <button type="submit" class="btn-primary">Create Short Link</button>
                    <button type="button" class="btn-secondary" onclick="generateCode()">Generate Random Code</button>
                </div>
            </form>
        </div>
        
        <div class="card">
            <h2>Your Short Links</h2>
            <div id="linksContainer">
                <div class="empty-state">Loading links...</div>
            </div>
        </div>
    </div>
    
    <script>
        let links = [];
        
        async function loadLinks() {
            try {
                const response = await fetch('/api/links');
                links = await response.json();
                renderLinks();
                updateStats();
            } catch (error) {
                console.error('Error loading links:', error);
                document.getElementById('linksContainer').innerHTML = '<div class="empty-state">Error loading links</div>';
            }
        }
        
        function renderLinks() {
            const container = document.getElementById('linksContainer');
            
            if (!links || links.length === 0) {
                container.innerHTML = '<div class="empty-state">No links yet. Create your first short link!</div>';
                return;
            }
            
            const baseUrl = window.location.protocol + '//' + window.location.host.replace(':4567', ':8080');
            
            const table = `
                <table class="links-table">
                    <thead>
                        <tr>
                            <th>Short Link</th>
                            <th>Destination</th>
                            <th>Clicks</th>
                            <th>Created</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${links.map(link => `
                            <tr>
                                <td><a href="${baseUrl}/${link.short_code}" target="_blank" class="short-link">${link.short_code}</a></td>
                                <td style="max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">${link.long_url}</td>
                                <td>${link.clicks}</td>
                                <td>${new Date(link.created_at).toLocaleDateString()}</td>
                                <td><button class="btn-delete" onclick="deleteLink('${link.short_code}')">Delete</button></td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            `;
            
            container.innerHTML = table;
        }
        
        function updateStats() {
            document.getElementById('totalLinks').textContent = links.length;
            const totalClicks = links.reduce((sum, link) => sum + link.clicks, 0);
            document.getElementById('totalClicks').textContent = totalClicks;
        }
        
        async function generateCode() {
            try {
                const response = await fetch('/api/generate-code');
                const data = await response.json();
                document.getElementById('shortCode').value = data.code;
            } catch (error) {
                console.error('Error generating code:', error);
            }
        }
        
        document.getElementById('createForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const shortCode = document.getElementById('shortCode').value;
            const longUrl = document.getElementById('longUrl').value;
            
            try {
                const response = await fetch('/api/links', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ short_code: shortCode, long_url: longUrl })
                });
                
                if (response.ok) {
                    showMessage('Short link created successfully!', 'success');
                    document.getElementById('createForm').reset();
                    loadLinks();
                } else {
                    const error = await response.text();
                    showMessage('Error: ' + error, 'error');
                }
            } catch (error) {
                showMessage('Error creating link: ' + error.message, 'error');
            }
        });
        
        async function deleteLink(shortCode) {
            if (!confirm('Are you sure you want to delete this link?')) return;
            
            try {
                const response = await fetch(`/api/links/${shortCode}`, { method: 'DELETE' });
                
                if (response.ok) {
                    showMessage('Link deleted successfully!', 'success');
                    loadLinks();
                } else {
                    showMessage('Error deleting link', 'error');
                }
            } catch (error) {
                showMessage('Error: ' + error.message, 'error');
            }
        }
        
        function showMessage(text, type) {
            const msg = document.getElementById('message');
            msg.textContent = text;
            msg.className = `message ${type}`;
            msg.style.display = 'block';
            setTimeout(() => { msg.style.display = 'none'; }, 5000);
        }
        
        // Load links on page load
        loadLinks();
        
        // Refresh links every 10 seconds
        setInterval(loadLinks, 10000);
    </script>
</body>
</html>require 'sinatra'
require 'sinatra/json'
require 'net/http'
require 'json'
require 'uri'

# Configuration
GO_SERVICE_URL = ENV['GO_SERVICE_URL'] || 'http://localhost:8080'

# Enable CORS
before do
  headers 'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => ['GET', 'POST', 'DELETE', 'OPTIONS'],
          'Access-Control-Allow-Headers' => 'Content-Type'
end

options '*' do
  200
end

# Homepage - Management Interface
get '/' do
  erb :index
end

# API: Get all links
get '/api/links' do
  uri = URI("#{GO_SERVICE_URL}/api/links")
  response = Net::HTTP.get_response(uri)
  
  content_type :json
  response.body
end

# API: Create a new short link
post '/api/links' do
  data = JSON.parse(request.body.read)
  
  # Validate input
  if data['short_code'].nil? || data['short_code'].empty?
    halt 400, json({ error: 'Short code is required' })
  end
  
  if data['long_url'].nil? || data['long_url'].empty?
    halt 400, json({ error: 'Long URL is required' })
  end
  
  # Validate URL format
  unless data['long_url'] =~ URI::DEFAULT_PARSER.make_regexp(['http', 'https'])
    halt 400, json({ error: 'Invalid URL format' })
  end
  
  # Validate short code format (alphanumeric only)
  unless data['short_code'] =~ /^[a-zA-Z0-9_-]+$/
    halt 400, json({ error: 'Short code must be alphanumeric (with _ or -)' })
  end
  
  # Forward to Go service
  uri = URI("#{GO_SERVICE_URL}/api/links")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
  request.body = data.to_json
  
  response = http.request(request)
  
  status response.code.to_i
  content_type :json
  response.body
end

# API: Delete a link
delete '/api/links/:short_code' do
  short_code = params[:short_code]
  
  uri = URI("#{GO_SERVICE_URL}/api/links/#{short_code}")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Delete.new(uri.path)
  
  response = http.request(request)
  
  status response.code.to_i
  content_type :json
  json({ message: 'Link deleted successfully' })
end

# Generate random short code
get '/api/generate-code' do
  code = (0...6).map { ('a'..'z').to_a[rand(26)] }.join
  json({ code: code })
end

__END__

@@index
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rayphoenix - URL Shortener</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0a1929;
            min-height: 100vh;
            padding: 20px;
            color: #e3e8ef;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        header {
            text-align: center;
            margin-bottom: 40px;
        }
        
        h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            font-weight: 700;
            color: #e3e8ef;
            letter-spacing: -0.5px;
        }
        
        .subtitle {
            font-size: 1.1em;
            color: #8b93a7;
            font-weight: 400;
        }
        
        .card {
            background: #132f4c;
            border-radius: 8px;
            padding: 30px;
            box-shadow: 0 4px 16px rgba(0,0,0,0.3);
            margin-bottom: 30px;
            border: 1px solid #1e4976;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #b0bac9;
        }
        
        input {
            width: 100%;
            padding: 12px;
            border: 1px solid #1e4976;
            border-radius: 6px;
            font-size: 15px;
            transition: border-color 0.3s;
            background: #0a1929;
            color: #e3e8ef;
            font-family: 'Inter', sans-serif;
        }
        
        input:focus {
            outline: none;
            border-color: #4a9eff;
        }
        
        .button-group {
            display: flex;
            gap: 10px;
        }
        
        button {
            flex: 1;
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }
        
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(102, 126, 234, 0.4);
        }
        
        .btn-secondary {
            background: #f0f0f0;
            color: #333;
        }
        
        .btn-secondary:hover {
            background: #e0e0e0;
        }
        
        .links-table {
            width: 100%;
            border-collapse: collapse;
        }
        
        .links-table th {
            background: #f8f9fa;
            padding: 12px;
            text-align: left;
            font-weight: 600;
            color: #555;
            border-bottom: 2px solid #dee2e6;
        }
        
        .links-table td {
            padding: 12px;
            border-bottom: 1px solid #dee2e6;
        }
        
        .links-table tr:hover {
            background: #f8f9fa;
        }
        
        .short-link {
            color: #667eea;
            font-weight: 600;
            text-decoration: none;
        }
        
        .short-link:hover {
            text-decoration: underline;
        }
        
        .btn-delete {
            background: #dc3545;
            color: white;
            padding: 6px 12px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
        }
        
        .btn-delete:hover {
            background: #c82333;
        }
        
        .stats {
            display: flex;
            justify-content: space-around;
            margin-bottom: 30px;
        }
        
        .stat-box {
            text-align: center;
            padding: 20px;
            background: white;
            border-radius: 12px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
            flex: 1;
            margin: 0 10px;
        }
        
        .stat-number {
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
        }
        
        .stat-label {
            color: #666;
            margin-top: 5px;
        }
        
        .message {
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: none;
        }
        
        .message.success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .message.error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .empty-state {
            text-align: center;
            padding: 40px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Rayphoenix</h1>
            <p class="subtitle">Lightning-fast URL shortening</p>
        </header>
        
        <div class="stats">
            <div class="stat-box">
                <div class="stat-number" id="totalLinks">0</div>
                <div class="stat-label">Total Links</div>
            </div>
            <div class="stat-box">
                <div class="stat-number" id="totalClicks">0</div>
                <div class="stat-label">Total Clicks</div>
            </div>
        </div>
        
        <div class="card">
            <h2>Create Short Link</h2>
            <div id="message" class="message"></div>
            <form id="createForm">
                <div class="form-group">
                    <label for="shortCode">Short Code</label>
                    <input type="text" id="shortCode" placeholder="e.g., github" required>
                </div>
                <div class="form-group">
                    <label for="longUrl">Long URL</label>
                    <input type="url" id="longUrl" placeholder="https://example.com/very/long/url" required>
                </div>
                <div class="button-group">
                    <button type="submit" class="btn-primary">Create Short Link</button>
                    <button type="button" class="btn-secondary" onclick="generateCode()">Generate Random Code</button>
                </div>
            </form>
        </div>
        
        <div class="card">
            <h2>Your Short Links</h2>
            <div id="linksContainer">
                <div class="empty-state">Loading links...</div>
            </div>
        </div>
    </div>
    
    <script>
        let links = [];
        
        async function loadLinks() {
            try {
                const response = await fetch('/api/links');
                links = await response.json();
                renderLinks();
                updateStats();
            } catch (error) {
                console.error('Error loading links:', error);
                document.getElementById('linksContainer').innerHTML = '<div class="empty-state">Error loading links</div>';
            }
        }
        
        function renderLinks() {
            const container = document.getElementById('linksContainer');
            
            if (!links || links.length === 0) {
                container.innerHTML = '<div class="empty-state">No links yet. Create your first short link!</div>';
                return;
            }
            
            const baseUrl = window.location.protocol + '//' + window.location.host.replace(':4567', ':8080');
            
            const table = `
                <table class="links-table">
                    <thead>
                        <tr>
                            <th>Short Link</th>
                            <th>Destination</th>
                            <th>Clicks</th>
                            <th>Created</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${links.map(link => `
                            <tr>
                                <td><a href="${baseUrl}/${link.short_code}" target="_blank" class="short-link">${link.short_code}</a></td>
                                <td style="max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">${link.long_url}</td>
                                <td>${link.clicks}</td>
                                <td>${new Date(link.created_at).toLocaleDateString()}</td>
                                <td><button class="btn-delete" onclick="deleteLink('${link.short_code}')">Delete</button></td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            `;
            
            container.innerHTML = table;
        }
        
        function updateStats() {
            document.getElementById('totalLinks').textContent = links.length;
            const totalClicks = links.reduce((sum, link) => sum + link.clicks, 0);
            document.getElementById('totalClicks').textContent = totalClicks;
        }
        
        async function generateCode() {
            try {
                const response = await fetch('/api/generate-code');
                const data = await response.json();
                document.getElementById('shortCode').value = data.code;
            } catch (error) {
                console.error('Error generating code:', error);
            }
        }
        
        document.getElementById('createForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const shortCode = document.getElementById('shortCode').value;
            const longUrl = document.getElementById('longUrl').value;
            
            try {
                const response = await fetch('/api/links', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ short_code: shortCode, long_url: longUrl })
                });
                
                if (response.ok) {
                    showMessage('Short link created successfully!', 'success');
                    document.getElementById('createForm').reset();
                    loadLinks();
                } else {
                    const error = await response.text();
                    showMessage('Error: ' + error, 'error');
                }
            } catch (error) {
                showMessage('Error creating link: ' + error.message, 'error');
            }
        });
        
        async function deleteLink(shortCode) {
            if (!confirm('Are you sure you want to delete this link?')) return;
            
            try {
                const response = await fetch(`/api/links/${shortCode}`, { method: 'DELETE' });
                
                if (response.ok) {
                    showMessage('Link deleted successfully!', 'success');
                    loadLinks();
                } else {
                    showMessage('Error deleting link', 'error');
                }
            } catch (error) {
                showMessage('Error: ' + error.message, 'error');
            }
        }
        
        function showMessage(text, type) {
            const msg = document.getElementById('message');
            msg.textContent = text;
            msg.className = `message ${type}`;
            msg.style.display = 'block';
            setTimeout(() => { msg.style.display = 'none'; }, 5000);
        }
        
        // Load links on page load
        loadLinks();
        
        // Refresh links every 10 seconds
        setInterval(loadLinks, 10000);
    </script>
</body>
</html>