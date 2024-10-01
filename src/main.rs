use std::io::Error;
use sqlx::PgPool;
use zero2prod::startup::run;
use zero2prod::configuration::get_configuration;

#[tokio::main]
async fn main() -> Result<(), Error> {
    // Panic if we can't read configuration
    let configuration = get_configuration().expect("Failed to read configuration file.");
    let connection_pool = PgPool::connect(&configuration.database.connection_string()).await.expect("Failed to connect to Postgres.");
    let address = format!("127.0.0.1:{}", configuration.application_port);
    let listener = std::net::TcpListener::bind(address)?;
    run(listener, connection_pool)?.await
}