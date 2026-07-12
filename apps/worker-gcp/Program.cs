using System.Text;
using System.Text.Json;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var dbUser = Environment.GetEnvironmentVariable("DB_USER") ?? "app_user";
var dbPass = Environment.GetEnvironmentVariable("DB_PASSWORD") ?? "";
var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? "votes";
var dbHost = Environment.GetEnvironmentVariable("DB_HOST") ?? "localhost";

var connString = $"Host={dbHost};Username={dbUser};Password={dbPass};Database={dbName}";

// Ensure votes table exists at startup
using (var initConn = new NpgsqlConnection(connString))
{
    await initConn.OpenAsync();
    var cmd = initConn.CreateCommand();
    cmd.CommandText = """
        CREATE TABLE IF NOT EXISTS votes (
            id VARCHAR(255) NOT NULL UNIQUE,
            vote VARCHAR(255) NOT NULL
        )
    """;
    await cmd.ExecuteNonQueryAsync();
}

app.MapGet("/healthz", () => Results.Ok("healthy"));

// PubSub push endpoint
app.MapPost("/", async (HttpContext context) =>
{
    using var reader = new StreamReader(context.Request.Body);
    var body = await reader.ReadToEndAsync();

    using var doc = JsonDocument.Parse(body);
    var message = doc.RootElement.GetProperty("message");
    var raw = message.GetProperty("data").GetString()!;

    // PubSub push delivers data as base64
    var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(raw));
    using var voteDoc = JsonDocument.Parse(decoded);
    var voterId = voteDoc.RootElement.GetProperty("voter_id").GetString()!;
    var vote = voteDoc.RootElement.GetProperty("vote").GetString()!;

    Console.WriteLine($"Processing vote for '{vote}' by '{voterId}'");

    using var conn = new NpgsqlConnection(connString);
    await conn.OpenAsync();

    try
    {
        using var insert = new NpgsqlCommand(
            "INSERT INTO votes (id, vote) VALUES (@id, @vote)", conn);
        insert.Parameters.AddWithValue("@id", voterId);
        insert.Parameters.AddWithValue("@vote", vote);
        await insert.ExecuteNonQueryAsync();
    }
    catch (PostgresException ex) when (ex.SqlState == "23505")
    {
        // Already voted — update their choice
        using var update = new NpgsqlCommand(
            "UPDATE votes SET vote = @vote WHERE id = @id", conn);
        update.Parameters.AddWithValue("@vote", vote);
        update.Parameters.AddWithValue("@id", voterId);
        await update.ExecuteNonQueryAsync();
    }

    return Results.Accepted();
});

app.Run();
