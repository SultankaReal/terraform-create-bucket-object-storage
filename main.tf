#Link to terraform documentation - https://registry.tfpla.net/providers/yandex-cloud/yandex/latest/docs/resources/storage_bucket

# Create SA
resource "yandex_iam_service_account" "sa" {
  folder_id = var.default_folder_id
  name      = "new-service-account-for-bucket1994"
}

# Grant permission 'admin' to service account
resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = var.default_folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

# Create Static Access Keys 
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

# Create kms-key
resource "yandex_kms_symmetric_key" "symmetric_key" {
  name = "ayo-kms-symmetric-key"
  default_algorithm = "AES_256"
}

#Create bucket
resource "yandex_storage_bucket" "bucket" {
  depends_on = [yandex_iam_service_account.sa, yandex_resourcemanager_folder_iam_member.sa-editor, yandex_iam_service_account_static_access_key.sa-static-key, yandex_kms_symmetric_key.symmetric_key]
  bucket = "nursultan-bucket"
  acl    = "private" //The predefined ACL to apply. Defaults to private. Conflicts with grant
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.symmetric_key.id
        sse_algorithm = "aws:kms" //The server-side encryption algorithm to use. Single valid value is aws:kms
    }
  }
  }

  versioning {
    enabled = true //Enable versioning. Once you version-enable a bucket, it can never return to an unversioned state. You can, however, suspend versioning on that bucket
  }

  lifecycle_rule {
    id      = "log"
    enabled = true

    prefix = "log/"

    transition { //Specifies a period in the object's transitions
      days          = 30
      storage_class = "COLD"
    }

    expiration {
      days = 90
      expired_object_delete_marker = true
    }
  }
}