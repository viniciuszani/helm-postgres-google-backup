# Postgres Google Backup

This helm chart extends [stable/postgresql](https://github.com/helm/charts/tree/master/stable/postgresql) by adding a cronjob that performs backups and sends email statuses using [SendGrid API](https://sendgrid.com/docs/API_Reference/index.html).

# Prerequisites

- Kubernetes 1.10+
- PV provisioner support in the underlying infrastructure
- `gsutil` and `gcloud` from [Google Cloud SDK](https://cloud.google.com/sdk/)
  - Also, you need to be logged in (`gcloud init`)
- A [SendGrid API key](https://sendgrid.com/docs/ui/account-and-settings/api-keys/) with permission to send emails

# Installing

1. Create the Google service account and bucket using the `google-account-helper.sh`;
```console
$ ./google-account-helper.sh google-project-name bucket-name-to-create bucket-location bucket-storage-class
```
2. Make a copy of `helm/values.yaml` and configure it;
3. Install `helm install --name my-release ./helm`
```console
$ helm install --name my-release ./helm
```

# Configuration

The following tables lists the configurable parameters and their default values.
In addition to that, you can apply [all the configurations of the stable/postgresql chart](https://github.com/helm/charts/tree/master/stable/postgresql).
Just prepend `postgresql.` to the value to be overridden, since it is a subchart.

| Parameter                                     | Description                                                                                             | Default                                  |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------- | -----------------------------------------|
| `postgresql.postgresqlDatabase`               | PostgreSQL database                                                                                     | `nil`                                    |
| `postgresql.postgresqlUsername`               | PostgreSQL username                                                                                     | `nil`                                    |
| `postgresql.postgresqlPassword`               | PostgreSQL username                                                                                     | `nil`                                    |
| `backup.enabled`                              | Enables/disables the backup cronjob                                                                     | `false`                                  |
| `backup.googleServiceAccount`                 | The Google Service account created by you or the helper, as raw JSON file                               | `nil`                                    |
| `backup.bucket`                               | The Google Cloud Storage bucket where the backups are going to be stored                                | `nil`                                    |
| `backup.schedule`                             | Crontab-like schedule to perform backups                                                                | `5 0 * * *` (daily backups at 5 AM)      |
| `backup.volumeSize`                           | Volume size where the backups are stored before being sent to the cloud                                 | `1Gi`                                    |
| `backup.email.enabled`                        | Enables/disables email notifications after job completion                                               | `false`                                  |
| `backup.email.sendgridApiKey`                 | The SendGrid API key (SG.xxxx....)                                                                      | `nil`                                    |
| `backup.email.from`                           | Sender address that will be used                                                                        | `nil`                                    |
| `backup.email.to`                             | Receiver address                                                                                        | `nil`                                    |
| `backup.email.success.subject`                | The email subject in case of success                                                                    | `[Backup Job] [%DATE%] Success`          |
| `backup.email.success.body`                   | The email body in case of success                                                                       | HTML content. See the `values.yaml`      |
| `backup.email.error.subject`                  | The email subject in case of error                                                                      | `[Backup Job] [%DATE%] Failed`           |
| `backup.email.error.body`                     | The email body in case of error                                                                         | HTML content. See the `values.yaml`      |


Use a YAML file to specify the values for the parameters while installing the chart. For example,

```console
$ helm install --name my-release -f values.yaml ./helm
```

Alternatively, specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```console
$ helm install --name my-release \
  --set postgresqlPassword=secretpassword,postgresqlDatabase=my-database \
    ./helm
```
